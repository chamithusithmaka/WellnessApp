// Firebase configuration for different platforms
// Generated from Firebase Console

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default Firebase options for the current platform
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Firebase is not configured for Linux.',
        );
      default:
        throw UnsupportedError(
          'Firebase is not configured for this platform.',
        );
    }
  }

  // ✅ WEB CONFIG - Updated with your Firebase Console values
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA8HQ_9wMOM21JGHwUhbIEireAkcocoUOM',
    appId: '1:225285136657:web:bae69909af13c01b29acb0',
    messagingSenderId: '225285136657',
    projectId: 'ai-wellness-app-922f6',
    authDomain: 'ai-wellness-app-922f6.firebaseapp.com',
    storageBucket: 'ai-wellness-app-922f6.firebasestorage.app',
    measurementId: 'G-NYR0Z734F2',
  );

  // Android config - from your google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBR9pEhx6G3wGpu0F5LI7StrD1EdeCoe0U',
    appId: '1:225285136657:android:4ce2220afaff9ac629acb0',
    messagingSenderId: '225285136657',
    projectId: 'ai-wellness-app-922f6',
    storageBucket: 'ai-wellness-app-922f6.firebasestorage.app',
  );

  // iOS config - add if needed
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: '225285136657',
    projectId: 'ai-wellness-app-922f6',
    storageBucket: 'ai-wellness-app-922f6.firebasestorage.app',
    iosBundleId: 'com.example.aiWellnessApp',
  );

  // macOS config
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: 'YOUR_MACOS_APP_ID',
    messagingSenderId: '225285136657',
    projectId: 'ai-wellness-app-922f6',
    storageBucket: 'ai-wellness-app-922f6.firebasestorage.app',
    iosBundleId: 'com.example.aiWellnessApp',
  );

  // Windows config
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'YOUR_WINDOWS_API_KEY',
    appId: 'YOUR_WINDOWS_APP_ID',
    messagingSenderId: '225285136657',
    projectId: 'ai-wellness-app-922f6',
    storageBucket: 'ai-wellness-app-922f6.firebasestorage.app',
  );
}