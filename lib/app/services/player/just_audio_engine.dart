import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'player_engine.dart';

/// [PlayerEngine] 的 just_audio（ExoPlayer / MediaCodec）实现。
///
/// 薄封装：持有唯一的 just_audio [AudioPlayer]，把所有方法与流归一化转发。
///
/// `useProxyForRequestHeaders: false` 让 HLS/音频源的请求头（Cookie）由
/// Android ExoPlayer 原生发送（DefaultHttpDataSource），而不是走 just_audio
/// 的 Dart 本地代理（代理不解析 `#EXT-X-MAP`，且会用 Dart HttpClient 连 NAS
/// IPv6 导致不可达）。
///
/// 缓冲参数（`AndroidLoadControl`，经官方 `AudioLoadConfiguration` 传入）：
/// 针对「服务器转码 HLS 缓冲到一半停」问题调大预缓冲窗口——
/// - `minBufferDuration` 60s / `maxBufferDuration` 150s：转码流是低码率
///   （32~128kbps），150s 最多几 MB 内存，ExoPlayer 会尽量多预缓冲，而不是
///   按默认 50s 封顶提前停住；
/// - `bufferForPlaybackAfterRebufferDuration` 15s：默认仅 5s——断流后只重缓冲
///   5s 就续播，网络一抖就反复卡。15s 让重连后攒够余量再播，减少反复顿挫；
/// - `prioritizeTimeOverSizeThresholds: true`：按时间阈值优先，避免 HLS 大
///   分段被默认字节阈值卡住预缓冲。
class JustAudioEngine implements PlayerEngine {
  JustAudioEngine()
      : _player = AudioPlayer(
          useProxyForRequestHeaders: false,
          audioLoadConfiguration: AudioLoadConfiguration(
            androidLoadControl: AndroidLoadControl(
              minBufferDuration: const Duration(seconds: 60),
              maxBufferDuration: const Duration(seconds: 150),
              bufferForPlaybackDuration: const Duration(seconds: 3),
              bufferForPlaybackAfterRebufferDuration:
                  const Duration(seconds: 15),
              prioritizeTimeOverSizeThresholds: true,
            ),
          ),
        );

  final AudioPlayer _player;

  @override
  EngineKind get kind => EngineKind.justAudio;

  @override
  Future<void> init() async {
    // ExoPlayer 无需额外初始化；原生流由 PlayerService 订阅本引擎的转发流。
  }

  @override
  Future<void> dispose() => _player.dispose();

  @override
  Future<void> loadQueue({
    required List<EngineItem> items,
    required int index,
    Duration? initialPosition,
    bool preload = false,
  }) {
    final sources = items
        .cast<JustAudioItem>()
        .map((e) => e.source)
        .toList(growable: false);
    return _player.setAudioSources(
      sources,
      initialIndex: index,
      initialPosition: initialPosition,
      preload: preload,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> seekToNext() => _player.seekToNext();

  @override
  Future<void> seekToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToIndex(int index) =>
      _player.seek(Duration.zero, index: index);

  @override
  Future<void> setLoopMode(EngineLoopMode mode) {
    final loop = switch (mode) {
      EngineLoopMode.single => LoopMode.one,
      EngineLoopMode.all => LoopMode.all,
      EngineLoopMode.none => LoopMode.off,
    };
    return _player.setLoopMode(loop);
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> insertItem(int index, EngineItem item) =>
      _player.insertAudioSource(index, (item as JustAudioItem).source);

  @override
  Future<void> insertItems(int index, List<EngineItem> items) {
    final sources = items
        .cast<JustAudioItem>()
        .map((e) => e.source)
        .toList(growable: false);
    return _player.insertAudioSources(index, sources);
  }

  @override
  Future<void> removeItem(int index) => _player.removeAudioSourceAt(index);

  @override
  Future<void> moveItem(int from, int to) => _player.moveAudioSource(from, to);

  @override
  Duration get position => _player.position;

  @override
  int? get currentIndex => _player.currentIndex;

  @override
  int get sequenceLength => _player.sequence.length;

  @override
  bool get hasLoadedSource => _player.audioSource != null;

  @override
  bool get playing => _player.playing;

  @override
  EngineProcessingState get processingState => switch (_player.processingState) {
        ProcessingState.idle => EngineProcessingState.idle,
        ProcessingState.loading => EngineProcessingState.loading,
        ProcessingState.ready => EngineProcessingState.ready,
        ProcessingState.buffering => EngineProcessingState.buffering,
        ProcessingState.completed => EngineProcessingState.completed,
      };

  @override
  EngineLoopMode get loopMode => switch (_player.loopMode) {
        LoopMode.off => EngineLoopMode.none,
        LoopMode.one => EngineLoopMode.single,
        LoopMode.all => EngineLoopMode.all,
      };

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<Duration> get bufferedPositionStream =>
      _player.bufferedPositionStream;

  @override
  Stream<EnginePlaybackState> get playbackStateStream =>
      _player.playerStateStream.map((s) => EnginePlaybackState(
            playing: s.playing,
            processingState: switch (s.processingState) {
              ProcessingState.idle => EngineProcessingState.idle,
              ProcessingState.loading => EngineProcessingState.loading,
              ProcessingState.ready => EngineProcessingState.ready,
              ProcessingState.buffering => EngineProcessingState.buffering,
              ProcessingState.completed => EngineProcessingState.completed,
            },
          ));

  @override
  Stream<EngineError> get errorStream => _player.errorStream.map(
      (e) => EngineError(message: e.message ?? '', index: e.index));

  @override
  Stream<int?> get currentIndexStream => _player.currentIndexStream;
}