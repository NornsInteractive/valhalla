"""Isolated SSH fixture for the ACP device durable test.

Binds 127.0.0.1:54323 only with fixture-only credentials. Exec requests are
served by asyncssh's process_factory so stdin/stdout/stderr are real byte
streams. Each command runs in an asyncio subprocess inheriting the isolated
HOME; no banner is written on exec.
"""
import argparse
import asyncio
import os
from pathlib import Path

import asyncssh


class Server(asyncssh.SSHServer):
    def begin_auth(self, username):
        return True

    def password_auth_supported(self):
        return True

    def validate_password(self, username, password):
        return username == "fixture" and password == "fixture-only"


async def process_factory(process):
    command = process.command
    if command is None:
        command = "/bin/sh -i"
    proc = await asyncio.create_subprocess_shell(
        command,
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        env=dict(os.environ),
        start_new_session=True,
    )

    async def pump_stdin():
        try:
            while True:
                data = await process.stdin.read(65536)
                if not data:
                    break
                proc.stdin.write(data)
                await proc.stdin.drain()
        except (BrokenPipeError, ConnectionError, OSError):
            pass
        finally:
            try:
                proc.stdin.close()
            except (BrokenPipeError, OSError):
                pass

    async def pump_stdout():
        while True:
            data = await proc.stdout.read(65536)
            if not data:
                break
            process.stdout.write(data)
            await process.stdout.drain()

    async def pump_stderr():
        while True:
            data = await proc.stderr.read(65536)
            if not data:
                break
            process.stderr.write(data)
            await process.stderr.drain()

    stdin_task = asyncio.ensure_future(pump_stdin())
    stdout_task = asyncio.ensure_future(pump_stdout())
    stderr_task = asyncio.ensure_future(pump_stderr())
    try:
        await proc.wait()
    finally:
        stdin_task.cancel()
        await asyncio.gather(stdin_task, return_exceptions=True)
        done, pending = await asyncio.wait(
            {stdout_task, stderr_task}, timeout=5
        )
        for task in pending:
            task.cancel()
        await asyncio.gather(stdout_task, stderr_task, return_exceptions=True)
        try:
            process.stdin.close()
        except Exception:
            pass
    process.exit(proc.returncode or 0)


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=54323)
    parser.add_argument("--ready-file", default=None)
    args = parser.parse_args()
    await asyncssh.create_server(
        Server,
        args.bind,
        args.port,
        server_host_keys=[asyncssh.generate_private_key("ssh-rsa")],
        process_factory=process_factory,
        encoding=None,
    )
    if args.ready_file:
        Path(args.ready_file).write_text("ready")
    await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
