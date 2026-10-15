class TransferProgressMeter {
  final Stopwatch _clock = Stopwatch()..start();
  int _sampleMicros = 0;
  int _sampleBytes;
  bool _published = false;
  double bytesPerSecond = 0;

  TransferProgressMeter({int initialBytes = 0}) : _sampleBytes = initialBytes;

  bool sample(int bytes, {bool force = false}) {
    final now = _clock.elapsedMicroseconds;
    final elapsed = now - _sampleMicros;
    if (_published && !force && elapsed < 150000) return false;
    if (_published && elapsed >= 150000 && bytes >= _sampleBytes) {
      final speed = (bytes - _sampleBytes) * 1000000 / elapsed;
      bytesPerSecond = bytesPerSecond == 0
          ? speed
          : bytesPerSecond * 0.5 + speed * 0.5;
    } else if (bytes < _sampleBytes) {
      bytesPerSecond = 0;
    }
    _sampleBytes = bytes;
    _sampleMicros = now;
    _published = true;
    return true;
  }
}
