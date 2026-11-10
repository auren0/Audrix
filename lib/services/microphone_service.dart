import 'dart:io';

import 'package:flutter/services.dart';

/// Mutes the default microphone while sounds are playing.
///
/// The native implementation lives in the Windows runner. On other platforms
/// (and in tests) every call becomes a no-op.
class MicrophoneService {
  static const MethodChannel _channel = MethodChannel('audrix/microphone');

  bool get isSupported => Platform.isWindows;

  bool _mutedByApp = false;
  bool? _previousMuteState;
  Future<void> _pending = Future<void>.value();

  Future<void> setMuted(bool muted) {
    _pending = _pending.then((_) => _applyMuted(muted));
    return _pending;
  }

  Future<void> _applyMuted(bool muted) async {
    if (!isSupported || muted == _mutedByApp) return;
    try {
      if (muted) {
        _previousMuteState = await _channel.invokeMethod<bool>('getMute');
        await _channel.invokeMethod<void>('setMute', true);
        _mutedByApp = true;
      } else {
        final restore = _previousMuteState ?? false;
        _previousMuteState = null;
        await _channel.invokeMethod<void>('setMute', restore);
        _mutedByApp = false;
      }
    } catch (_) {
      // No native handler (for example in tests or on other platforms).
    }
  }

  Future<void> restore() => setMuted(false);
}
