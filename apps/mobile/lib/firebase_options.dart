import 'dart:io';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Ibnik baby monitor.
/// If you download `google-services.json`, Firebase will also initialize natively.
class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) {
      return null;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return null;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDummyKeyForIbnikBabyMonitorInitPlaceholder',
    appId: '1:1450595981:android:ibnikbabymonitor',
    messagingSenderId: '1450595981',
    projectId: 'ibnik-baby-monitor',
    storageBucket: 'ibnik-baby-monitor.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDummyKeyForIbnikBabyMonitorInitPlaceholder',
    appId: '1:1450595981:ios:ibnikbabymonitor',
    messagingSenderId: '1450595981',
    projectId: 'ibnik-baby-monitor',
    storageBucket: 'ibnik-baby-monitor.firebasestorage.app',
    iosBundleId: 'com.charafeddine.ibnik',
  );
}
