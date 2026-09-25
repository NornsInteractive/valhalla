# Valhalla SMB

Local Flutter FFI plugin over vendored `libsmb2-6.2`
(`d67e213a5c4e7e4969fd81f0b95e4ca5831fbba1`). See `NOTICE` and the upstream
LGPL license. Credentials stay separate from paths. All operations are read-only.

The worker isolate owns its connection. Directory enumeration uses the public
raw CREATE / QUERY_DIRECTORY / CLOSE APIs, the upstream decoder and at most
64 KiB per response. It does not use `smb2_opendir`, which buffers an entire
directory. A consumer must acknowledge each page/chunk before the next read.
Traversal is depth-first, skips reparse points, and reports a visible error past
128 levels. Reads use 64-bit offsets and at most 256 KiB per chunk. Signing is
required; SMB1, unsigned guest access and Kerberos are not enabled. SMB3 server
encryption requirements are honored by libsmb2.

Cancellation uses a shared atomic flag and closes the native context. The poll
loop checks it every 100 ms; individual operations time out after 15 seconds.
The platform DNS resolver runs in the worker and retains the OS resolver's
timeout. Cancelled/failed scans must not delete previous indexed records.

Builds compile from source: Android API 24, iOS 13, macOS 10.15, Windows and
Linux. Apple builds use separate forwarding translation units so upstream
sources remain unchanged. Linux builds use the application's chosen toolchain
and do not bundle a binary requiring a newer glibc.

```sh
cmake -G Ninja -S src -B /tmp/valhalla-smb -DCMAKE_C_COMPILER=clang
cmake --build /tmp/valhalla-smb
flutter test
```

For the native integration check, install `impacket==0.12.0` in a temporary
Python environment, run `tool/test_server.py`, then:

```sh
dart run tool/smoke.dart /tmp/valhalla-smb/libvalhalla_smb.so
```

This fixture binds only localhost and verifies pagination, Unicode filenames,
reading beyond 4 GiB, cancellation and reconnection. Real NAS authentication,
SMB3 encryption, and each target OS still need their own device/server checks.
