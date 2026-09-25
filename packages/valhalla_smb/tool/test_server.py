"""Local-only fixture: pip install impacket==0.12.0, then run this script."""
from pathlib import Path
import tempfile

from impacket import smbserver
from impacket.ntlm import compute_lmhash, compute_nthash

with tempfile.TemporaryDirectory(prefix="valhalla-smb-") as location:
    root = Path(location)
    for index in range(2500):
        (root / f"track-{index:04d}.mp3").write_bytes(b"audio")
    (root / "照片.jpg").write_bytes(b"image")
    with (root / "large.mp4").open("wb") as media:
        media.seek(0x100000000 + 17)
        media.write(b"seek")
    (root / "excluded").mkdir()
    (root / "excluded" / "skip.mp3").write_bytes(b"skip")
    server = smbserver.SimpleSMBServer(listenAddress="127.0.0.1", listenPort=14455)
    server.addShare("media", str(root), readOnly="yes")
    server.setSMB2Support(True)
    server.addCredential("valhalla", 0, compute_lmhash("test-password"), compute_nthash("test-password"))
    print("SMB fixture ready on 127.0.0.1:14455", flush=True)
    server.start()
