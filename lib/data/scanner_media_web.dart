import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Owns the MediaStreams acquired while the QR reader starts.
/// mobile_scanner 7.4.3 stops decoding but leaves browser video tracks live.
/// Keep stream references independently, including delayed permission grants.
class ScannerMediaLease {
  static final _capturing = <ScannerMediaLease>[];
  static JSFunction? _original;
  final _streams = <web.MediaStream>[];
  final _cancelled = Completer<void>();
  bool _released = false;
  bool get released => _released;

  Future<void> captureWhile(Future<void> Function() start) async {
    final devices = web.window.navigator.mediaDevices;
    if (_capturing.isEmpty) {
      _original = devices.getProperty<JSFunction>('getUserMedia'.toJS);
      JSPromise<web.MediaStream> capture(JSAny? constraints) {
        final owner = _capturing.last;
        if (owner._released) {
          return Future<web.MediaStream>.error(
                  StateError('QR scanner is closed'))
              .toJS;
        }
        final result = _original!.callAsFunction(devices, constraints)
            as JSPromise<web.MediaStream>;
        final acquired = result.toDart.then((stream) {
          owner._streams.add(stream);
          if (owner._released) {
            owner.release();
            throw StateError('QR scanner is closed');
          }
          return stream;
        });
        // Do not leave SDK startup awaiting a dismissed browser permission
        // request. The acquired callback still releases any late video stream.
        return Future.any<web.MediaStream>([
          acquired,
          owner._cancelled.future.then<web.MediaStream>(
              (_) => throw StateError('QR scanner is closed')),
        ]).toJS;
      }

      devices.setProperty('getUserMedia'.toJS, capture.toJS);
    }
    _capturing.add(this);
    try {
      await start();
    } finally {
      _capturing.remove(this);
      if (_capturing.isEmpty) {
        devices.setProperty('getUserMedia'.toJS, _original);
        _original = null;
      }
    }
  }

  void release() {
    _released = true;
    if (!_cancelled.isCompleted) _cancelled.complete();
    for (final stream in _streams) {
      for (final track in stream.getTracks().toDart) {
        track.stop();
      }
    }
    _streams.clear();
  }
}
