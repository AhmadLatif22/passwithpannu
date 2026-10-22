import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(firestoreProvider)),
);

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <AppNotification>[]);
  return ref.watch(notificationRepositoryProvider).watch(uid);
});

final unreadNotificationsProvider = Provider<int>(
  (ref) =>
      ref
          .watch(notificationsProvider)
          .valueOrNull
          ?.where((n) => !n.isRead)
          .length ??
      0,
);
