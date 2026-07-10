// lib/core/services/connectivity_service.dart
// Monitors internet connectivity and shows a toast when offline.

import 'dart:async';
import 'package:flutter/material.dart';

/// Lightweight connectivity checker using HTTP (no extra package needed).
/// Integrated into AuthInterceptor so "no internet" toasts appear automatically.
class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void setOnline(bool online) {
    if (online == _isOnline) return;
    _isOnline = online;
    _controller.add(online);
  }

  void dispose() {
    _controller.close();
  }
}

/// Shows a "No internet connection" snack bar that persists until reconnected.
class OfflineBanner extends StatefulWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  late final StreamSubscription<bool> _sub;

  @override
  void initState() {
    super.initState();
    _sub = ConnectivityService.instance.onConnectivityChanged.listen((online) {
      if (!mounted) return;
      if (!online) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('No internet connection',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500)),
              ],
            ),
            backgroundColor: const Color(0xFF374151),
            duration: const Duration(days: 1), // dismiss manually
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
