"""Local, read-only DAV media fixture. Requires wsgidav, cheroot, imageio-ffmpeg.

Run in an isolated venv; this is test tooling, not an application dependency.
Credentials are deliberately public test values: nas / nas-fixture-only.
"""
import argparse
from pathlib import Path
import subprocess

import imageio_ffmpeg
from cheroot import wsgi
from wsgidav.wsgidav_app import WsgiDAVApp


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=18086)
    parser.add_argument("--root", default="/tmp/valhalla-nas-media-fixture")
    args = parser.parse_args()
    root = Path(args.root)
    root.mkdir(parents=True, exist_ok=True)
    encoder = imageio_ffmpeg.get_ffmpeg_exe()
    commands = [
        ["-f", "lavfi", "-i", "testsrc2=size=640x360:rate=24", "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=44100",
         "-t", "30", "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p", "-c:a", "aac", "-movflags", "+faststart", str(root / "Video 30s.mp4")],
        ["-f", "lavfi", "-i", "sine=frequency=440:sample_rate=44100", "-t", "60", "-metadata", "title=NAS test track",
         "-metadata", "artist=Valhalla", "-metadata", "album=Fixture", "-c:a", "libmp3lame", str(root / "Music 60s.mp3")],
        ["-f", "lavfi", "-i", "testsrc2=size=1600x900", "-frames:v", "1", str(root / "Photo.png")],
    ]
    for command in commands:
        if not Path(command[-1]).exists():
            subprocess.run([encoder, "-hide_banner", "-loglevel", "error", "-y", *command], check=True)
    app = WsgiDAVApp({
        "host": args.bind, "port": args.port,
        "provider_mapping": {"/": {"root": str(root), "readonly": True}},
        "simple_dc": {"user_mapping": {"*": {"nas": {"password": "nas-fixture-only"}}}},
        "http_authenticator": {"accept_basic": True, "accept_digest": False, "default_to_digest": False},
        "verbose": 1,
    })
    server = wsgi.Server((args.bind, args.port), app)
    try:
        server.start()
    except KeyboardInterrupt:
        server.stop()


if __name__ == "__main__":
    main()
