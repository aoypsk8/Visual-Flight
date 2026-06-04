import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../utils/flight_audio_assets.dart';

/// In-flight audio — uses `flight_cruise.mp3` only, looped from 0:08
class FlightAudioService {
  FlightAudioService() {
    unawaited(_configureSession());
  }

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _loopSub;
  bool _enabled = true;
  bool _playing = false;

  static final Map<String, bool> _assetCache = {};

  static final AudioContext _playbackContext = AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: {
        AVAudioSessionOptions.mixWithOthers,
        AVAudioSessionOptions.duckOthers,
      },
    ),
    android: AudioContextAndroid(
      isSpeakerphoneOn: true,
      stayAwake: true,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gain,
    ),
  );

  Future<void> _configureSession() async {
    try {
      await _player.setAudioContext(_playbackContext);
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
    } catch (_) {}
  }

  Future<bool> _hasCruiseAsset() async {
    const path = FlightAudioAssets.cruise;
    final cached = _assetCache[path];
    if (cached != null) return cached;
    try {
      await rootBundle.load(path);
      _assetCache[path] = true;
      return true;
    } catch (_) {
      _assetCache[path] = false;
      return false;
    }
  }

  /// Start playback during Live Flight — loops from 0:08
  Future<void> startFlight() async {
    if (!_enabled) return;
    await stopAll();
    if (!await _hasCruiseAsset()) return;

    try {
      _loopSub?.cancel();
      _loopSub = _player.onPlayerComplete.listen((_) {
        unawaited(_playLoopFromStart());
      });

      await _player.setReleaseMode(ReleaseMode.stop);
      _playing = true;
      await _playLoopFromStart();
    } catch (_) {
      _playing = false;
    }
  }

  Future<void> _playLoopFromStart() async {
    if (!_enabled || !_playing) return;
    try {
      await _player.play(
        AssetSource(_assetKey(FlightAudioAssets.cruise)),
        volume: FlightAudioAssets.liveVolume,
        position: FlightAudioAssets.cruiseLoopStart,
        ctx: _playbackContext,
      );
    } catch (_) {
      _playing = false;
    }
  }

  /// End of flight — stop audio (no separate landing sound)
  Future<void> playLanding() async {
    await stopAll();
  }

  Future<void> stopAll() async {
    _playing = false;
    await _loopSub?.cancel();
    _loopSub = null;
    try {
      await _player.stop();
    } catch (_) {}
  }

  void setEnabled(bool value) {
    _enabled = value;
    if (!value) {
      unawaited(stopAll());
    }
  }

  void dispose() {
    unawaited(stopAll());
    _player.dispose();
  }

  static String _assetKey(String fullPath) {
    if (fullPath.startsWith('assets/')) {
      return fullPath.substring('assets/'.length);
    }
    return fullPath;
  }
}
