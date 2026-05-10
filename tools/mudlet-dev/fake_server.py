#!/usr/bin/env python3
# Tiny telnet+GMCP server for headless Mudlet layout testing.
#
# Negotiates GMCP, drains anything the client sends back (Core.Hello,
# Core.Supports.Set, login attempts, …), and pushes a JSON fixture of
# {delay_ms, package, payload} entries as IAC SB GMCP frames.
#
# Usage:
#   fake_server.py <port> <fixture.json>
#
# Designed to be killed when run.sh tears down. Holds the connection
# open after the fixture is exhausted so Mudlet keeps rendering.

import asyncio
import json
import sys

IAC, SB, SE = 255, 250, 240
WILL, WONT, DO, DONT = 251, 252, 253, 254
GMCP = 201


def gmcp_frame(package: str, payload) -> bytes:
    body = package.encode("utf-8")
    if payload is not None:
        body += b" " + json.dumps(payload, ensure_ascii=False).encode("utf-8")
    body = body.replace(bytes([IAC]), bytes([IAC, IAC]))
    return bytes([IAC, SB, GMCP]) + body + bytes([IAC, SE])


async def drain(reader: asyncio.StreamReader) -> None:
    try:
        while True:
            chunk = await reader.read(4096)
            if not chunk:
                return
    except (ConnectionResetError, asyncio.CancelledError):
        return


async def handle(reader, writer, fixture):
    peer = writer.get_extra_info("peername")
    print(f"[fake_server] client connected: {peer}", flush=True)

    writer.write(bytes([IAC, WILL, GMCP]))
    await writer.drain()

    drainer = asyncio.create_task(drain(reader))

    try:
        await asyncio.sleep(0.5)
        for ev in fixture:
            await asyncio.sleep(ev.get("delay_ms", 0) / 1000.0)
            frame = gmcp_frame(ev["package"], ev.get("payload"))
            writer.write(frame)
            await writer.drain()
            print(f"[fake_server] sent {ev['package']}", flush=True)
        while not writer.is_closing():
            await asyncio.sleep(1)
    except (ConnectionResetError, BrokenPipeError):
        pass
    finally:
        drainer.cancel()
        try:
            writer.close()
            await writer.wait_closed()
        except Exception:
            pass


async def main(port: int, fixture_path: str) -> None:
    with open(fixture_path) as fh:
        fixture = json.load(fh)
    server = await asyncio.start_server(
        lambda r, w: handle(r, w, fixture), "127.0.0.1", port
    )
    print(f"[fake_server] listening on 127.0.0.1:{port}", flush=True)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("usage: fake_server.py <port> <fixture.json>", file=sys.stderr)
        sys.exit(2)
    try:
        asyncio.run(main(int(sys.argv[1]), sys.argv[2]))
    except KeyboardInterrupt:
        pass
