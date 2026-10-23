#!/usr/bin/env python3
"""Fake ACP agent for device durable test. No real commands."""
import json
import os
import sys
import time


def emit(obj):
    sys.stdout.write(json.dumps(obj, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def bump(path):
    with open(path, "a") as handle:
        handle.write("x\n")
        handle.flush()
        try:
            os.fsync(handle.fileno())
        except OSError:
            pass


def main():
    cfg = json.loads(sys.argv[1])
    session_id = cfg["sessionId"]
    chunks = int(cfg.get("chunks", 30))
    delay = float(cfg.get("chunkDelay", 1.0))
    prompt_count_file = cfg["promptCountFile"]

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            frame = json.loads(line)
        except json.JSONDecodeError:
            continue
        method = frame.get("method")
        rpc_id = frame.get("id")
        if method == "initialize":
            emit({"jsonrpc": "2.0", "id": rpc_id, "result": {
                "protocolVersion": 1,
                "agentCapabilities": {},
                "agentInfo": {"name": "fake-acp", "version": "1.0.0"},
            }})
        elif method in ("session/new", "session/load", "session/resume"):
            emit({"jsonrpc": "2.0", "id": rpc_id, "result": {
                "sessionId": session_id,
                "configOptions": [],
                "modes": None,
            }})
        elif method == "session/prompt":
            bump(prompt_count_file)
            for index in range(chunks):
                emit({"jsonrpc": "2.0", "method": "session/update", "params": {
                    "sessionId": session_id,
                    "update": {
                        "sessionUpdate": "agent_message_chunk",
                        "content": {"type": "text", "text": "chunk-%d" % index},
                    }}})
                if delay:
                    time.sleep(delay)
            emit({"jsonrpc": "2.0", "id": rpc_id, "result": {"stopReason": "end_turn"}})
        elif method == "session/cancel":
            emit({"jsonrpc": "2.0", "id": rpc_id, "result": {}})
        elif method is None and "id" in frame:
            # permission response or stray; ignore
            pass
        else:
            if rpc_id is not None:
                emit({"jsonrpc": "2.0", "id": rpc_id, "result": {}})


if __name__ == "__main__":
    main()
