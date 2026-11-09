import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class BackgroundMonitorService {
  static bool _isInitialized = false;

  /// Initializes the Android Foreground Service configuration
  static void init() {
    if (_isInitialized) return;
    _isInitialized = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'ibnik_monitor_service',
        channelName: 'Ibnik Baby Monitor Service',
        channelDescription: 'Maintains continuous audio and video streaming while screen is off',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Requests notification and battery optimization permissions so OS won't kill app
  static Future<void> requestPermissions() async {
    try {
      // 1. Notification permission (Android 13+)
      final notifPerm = await FlutterForegroundTask.checkNotificationPermission();
      if (notifPerm != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      // 2. Battery optimization exemption (Prevents Android Doze from putting app to sleep)
      final isIgnoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (!isIgnoring) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (e) {
      debugPrint('BackgroundMonitorService permission request notice: $e');
    }
  }

  /// Starts the persistent foreground service with a status notification
  static Future<bool> startMonitoringService({
    required String title,
    required String text,
  }) async {
    init();
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
        return true;
      }

      final receivePort = FlutterForegroundTask.receivePort;
      return await FlutterForegroundTask.startService(
        notificationTitle: title,
        notificationText: text,
        callback: _taskCallback,
      );
    } catch (e) {
      debugPrint('Error starting foreground service: $e');
      return false;
    }
  }

  /// Updates the notification text (e.g. noise alert or status change)
  static Future<void> updateNotification({
    required String title,
    required String text,
  }) async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
      }
    } catch (_) {}
  }

  /// Stops the foreground service
  static Future<bool> stopMonitoringService() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        return await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('Error stopping foreground service: $e');
    }
    return false;
  }
}

// Global top-level callback required by flutter_foreground_task
@pragma('vm:entry-point')
void _taskCallback() {
  FlutterForegroundTask.setTaskHandler(_MonitorTaskHandler());
}

class _MonitorTaskHandler extends TaskHandler {
  @override
  void onStart(DateTime timestamp, SendPort? sendPort) {
    debugPrint('Foreground monitor task started at $timestamp');
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    // Periodic heartbeat keeps process alive
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {
    debugPrint('Foreground monitor task destroyed at $timestamp');
  }
}
