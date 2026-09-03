// این فایل با اطلاعات پروژه Firebase واقعی (Raspina) پر شده است.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'این پلتفرم هنوز پیکربندی نشده. flutterfire configure را اجرا کنید.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBDNk_i5grmYXW-TZZI-qgJHsMc5svs5iQ',
    appId: '1:49135288570:web:d45bde8e80752e43498943',
    messagingSenderId: '49135288570',
    projectId: 'raspina-167b2',
    authDomain: 'raspina-167b2.firebaseapp.com',
    storageBucket: 'raspina-167b2.firebasestorage.app',
    measurementId: 'G-P7NC349VVN',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    storageBucket: 'REPLACE_ME',
  );
}
