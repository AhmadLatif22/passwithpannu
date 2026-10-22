import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_providers.dart';
import '../services/fcm_service.dart';
import 'dialogs.dart';

/// Wrap a signed-in shell: registers the device for push and shows foreground
/// messages as an in-app banner (the system tray handles background ones).
class PushBootstrap extends ConsumerStatefulWidget {
  const PushBootstrap({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<PushBootstrap> createState() => _PushBootstrapState();
}

class _PushBootstrapState extends ConsumerState<PushBootstrap> {
  StreamSubscription<dynamic>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = ref.read(currentUidProvider);
      if (uid == null || !mounted) return;
      final fcm = ref.read(fcmServiceProvider);
      try {
        final status = await fcm.register(uid);
        if (mounted) {
          ref.read(notificationPermissionProvider.notifier).state = status;
        }
      } catch (_) {
        // Push is best-effort; the in-app notification list still works.
      }
      _sub = fcm.foregroundMessages.listen((m) {
        final n = m.notification;
        if (n != null && mounted) {
          showSnack(context, [n.title, n.body].whereType<String>().join(': '));
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
