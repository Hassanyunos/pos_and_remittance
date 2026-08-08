import 'dart:async';

import 'package:flutter/material.dart';

enum AppNoticeType { error, info, success, warning }

class AppNotice {
  AppNotice._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    String message, {
    AppNoticeType type = AppNoticeType.info,
    Duration duration = const Duration(seconds: 1),
  }) {
    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _dismissCurrent();

    final style = _style(type);
    _entry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: Material(
            color: Colors.black26,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: style.background,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(style.icon, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(_entry!);
    _timer = Timer(duration, _dismissCurrent);
  }

  static void success(String message) {
    show(message, type: AppNoticeType.success);
  }

  static void error(String message) {
    show(message, type: AppNoticeType.error);
  }

  static void warning(String message) {
    show(message, type: AppNoticeType.warning);
  }

  static void info(String message) {
    show(message, type: AppNoticeType.info);
  }

  static void _dismissCurrent() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  static _NoticeStyle _style(AppNoticeType type) {
    switch (type) {
      case AppNoticeType.error:
        return const _NoticeStyle(
          background: Color(0xFFD32F2F),
          icon: Icons.error_outline,
        );
      case AppNoticeType.info:
        return const _NoticeStyle(
          background: Color(0xFF212121),
          icon: Icons.info_outline,
        );
      case AppNoticeType.success:
        return const _NoticeStyle(
          background: Color(0xFF2E7D32),
          icon: Icons.check_circle_outline,
        );
      case AppNoticeType.warning:
        return const _NoticeStyle(
          background: Color(0xFFEF6C00),
          icon: Icons.warning_amber_outlined,
        );
    }
  }
}

class _NoticeStyle {
  const _NoticeStyle({required this.background, required this.icon});

  final Color background;
  final IconData icon;
}
