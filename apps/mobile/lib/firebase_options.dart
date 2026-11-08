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
    apiKey: 'AIzaSyA73rAr1Hm-hRTyEPexmOlkHIQSPpKpF_o',
    appId: '1:272115978287:android:57d211169daeabedfe76da',
    messagingSenderId: '272115978287',
    projectId: 'ibnik-ces',
    storageBucket: 'ibnik-ces.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA73rAr1Hm-hRTyEPexmOlkHIQSPpKpF_o',
    appId: '1:272115978287:ios:57d211169daeabedfe76da',
    messagingSenderId: '272115978287',
    projectId: 'ibnik-ces',
    storageBucket: 'ibnik-ces.firebasestorage.app',
    iosBundleId: 'com.charafeddine.ibnik',
  );
}
