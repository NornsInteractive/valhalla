import asyncio
import sys
from pathlib import Path
import asyncssh

report = Path(sys.argv[1])
report.mkdir(parents=True, exist_ok=True)

class Session(asyncssh.SSHServerSession):
    def connection_made(self, channel):
        self.channel = channel
    def pty_requested(self, *args):
        return True
    def shell_requested(self):
        return True
    def session_started(self):
        self.channel.write('fixture> ')
    def data_received(self, data, datatype):
        with (report/'ssh-input.bin').open('ab') as file:
            file.write(data.encode('utf-8'))
        self.channel.write(data)

class Server(asyncssh.SSHServer):
    def begin_auth(self, username):
        return True
    def password_auth_supported(self):
        return True
    def validate_password(self, username, password):
        return username == 'fixture' and password == 'fixture-only'
    def session_requested(self):
        return Session()

async def main():
    await asyncssh.create_server(Server, '127.0.0.1', 54322,
                                server_host_keys=[asyncssh.generate_private_key('ssh-rsa')],
                                encoding='utf-8')
    (report/'ssh-ready').write_text('ready')
    await asyncio.Future()

asyncio.run(main())
