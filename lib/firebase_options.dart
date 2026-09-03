// این فایل باید با ابزار رسمی FlutterFire جایگزین شود.
// (نمی‌توان از اینجا به پروژه Firebase شما متصل شد چون نیاز به
// حساب Firebase شخصی شما و اجرای دستور محلی دارد.)
//
// مراحل:
// 1) در https://console.firebase.google.com یک پروژه جدید بسازید (رایگان/Spark).
// 2) Authentication (روش Email/Password) و Cloud Firestore و Storage را فعال کنید.
// 3) روی سیستم خودتان اجرا کنید:
//      dart pub global activate flutterfire_cli
//      flutterfire configure
//    این دستور به‌صورت خودکار همین فایل را با کلیدهای واقعی پروژه شما بازنویسی می‌کند.
//
// تا قبل از آن، پروژه اجرا نمی‌شود چون این‌جا فقط Placeholder است.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'نسخه اول این پروژه فقط Android است (طبق پرامپت اولیه).',
      );
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    storageBucket: 'REPLACE_ME',
  );
}
