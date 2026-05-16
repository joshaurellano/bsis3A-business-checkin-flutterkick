import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmanager/workmanager.dart';

// ─── Background task name ─────────────────────────────────────────────────────

const kExpiryCheckTask = 'expiry_check_task';

// ─── Top-level callback required by workmanager ───────────────────────────────
// Must be a top-level function (not inside a class).

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == kExpiryCheckTask) {
      await NotificationService().init();
      await NotificationService().checkAndNotifyExpiring();
    }
    return Future.value(true);
  });
}

// ─── Notification Service ─────────────────────────────────────────────────────

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ─── Notification channels ────────────────────────────────────────────────

  static const _expiredChannel = AndroidNotificationDetails(
    'expired_medicines',
    'Expired Medicines',
    channelDescription: 'Alerts for medicines that have already expired',
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFFE53935),
    playSound: true,
  );

  static const _soonChannel = AndroidNotificationDetails(
    'expiring_soon_medicines',
    'Expiring Soon',
    channelDescription: 'Alerts for medicines expiring within 6 months',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    color: Color(0xFFFF9800),
  );

  // ─── Init ─────────────────────────────────────────────────────────────────

Future<void> init() async {
  if (_initialized) return;
  _initialized = true;

  tz.initializeTimeZones();
  try {
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz.toString()));
  } catch (_) {
    // Fallback to UTC if timezone not found
    tz.setLocalLocation(tz.UTC);
  }

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  await _plugin.initialize(
    const InitializationSettings(android: android, iOS: ios),
  );

}

  // ─── Register background task ─────────────────────────────────────────────

  Future<void> registerBackgroundTask() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    // Runs every 12 hours. Workmanager minimum is 15 minutes on Android
    // but we use 12 hours so it roughly catches morning and evening.
    await Workmanager().registerPeriodicTask(
      kExpiryCheckTask,
      kExpiryCheckTask,
      frequency: const Duration(hours: 12),
      initialDelay: const Duration(seconds: 10),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  // ─── Core check ───────────────────────────────────────────────────────────

  Future<void> checkAndNotifyExpiring() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('invoice_items')
          .get();

      final now = DateTime.now();
      final List<String> expiredNames = [];
      final List<String> soonNames = [];

      for (final doc in snap.docs) {
        final data = doc.data();
        final desc = data['description']?.toString() ?? '(unnamed)';
        final expiryRaw = data['expiryDate']?.toString() ?? '';
        final expiry = _parseExpiry(expiryRaw);
        if (expiry == null) continue;

        final diff = expiry.difference(now).inDays;

        if (diff < 0) {
          expiredNames.add(desc);
        } else if (diff <= 180) {
          soonNames.add(desc);
        }
      }

      // Show expired notification
      if (expiredNames.isNotEmpty) {
        await _plugin.show(
          1,
          '⚠ ${expiredNames.length} Medicine(s) Expired',
          expiredNames.length == 1
              ? '${expiredNames.first} has already expired.'
              : '${expiredNames.first} and ${expiredNames.length - 1} other(s) have expired.',
          const NotificationDetails(android: _expiredChannel),
        );
      }

      // Show expiring soon notification
      if (soonNames.isNotEmpty) {
        await _plugin.show(
          2,
          '🕐 ${soonNames.length} Medicine(s) Expiring Soon',
          soonNames.length == 1
              ? '${soonNames.first} expires within 6 months.'
              : '${soonNames.first} and ${soonNames.length - 1} other(s) expire within 6 months.',
          const NotificationDetails(android: _soonChannel),
        );
      }
    } catch (e) {
      debugPrint('Notification check error: $e');
    }
  }

  // ─── Expiry parser (mirrors dashboard logic) ──────────────────────────────

  DateTime? _parseExpiry(String value) {
    if (value.isEmpty) return null;
    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;
    try {
      final parts = value.split(RegExp(r'[\/\-]'));
      if (parts.length == 3) {
        final nums = parts.map((p) => int.tryParse(p) ?? 0).toList();
        if (nums[2] > 99) return DateTime(nums[2], nums[0], nums[1]);
        return DateTime(2000 + nums[2], nums[1], nums[0]);
      }
      if (parts.length == 2) {
        final a = int.tryParse(parts[0]) ?? 1;
        final b = int.tryParse(parts[1]) ?? 2025;
        if (b > 99) return DateTime(b, a);
        if (a > 12) return DateTime(2000 + a, b);
        return DateTime(2000 + b, a);
      }
    } catch (_) {}
    return null;
  }
}