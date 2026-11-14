/// Native camera tracks are released by MobileScannerController.stop().
class ScannerMediaLease {
  bool released = false;
  Future<void> captureWhile(Future<void> Function() start) => start();
  void release() {
    released = true;
  }
}
