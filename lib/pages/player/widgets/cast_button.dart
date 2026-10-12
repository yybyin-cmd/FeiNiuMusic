import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../app/services/player_service.dart';
import '../../../components/feedback/app_toast.dart';

/// 播放页右上角投屏按钮（存根：DLNA 功能已移除，保留占位）。
class CastButton extends StatelessWidget {
  final Signal<SongEntity?> songSignal;

  const CastButton({super.key, required this.songSignal});

  bool get _isAndroid =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || Platform.isAndroid);

  @override
  Widget build(BuildContext context) {
    // DLNA 功能暂不可用，返回空
    if (!_isAndroid) return const SizedBox.shrink();
    return const SizedBox.shrink();
  }
}