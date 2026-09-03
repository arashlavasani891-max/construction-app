# مراحل راه‌اندازی پروژه کنترل پروژه

## 0) نکته مهم درباره Firebase Storage
از 3 فوریه 2026 برای استفاده از Cloud Storage for Firebase باید پروژه روی پلن Blaze باشد. استفاده رایگان/بدون هزینه همچنان ممکن است داخل سهمیه‌های بدون هزینه Blaze انجام شود، اما اتصال Billing لازم است. بنابراین اگر عکس‌های پیشرفت برای شما ضروری هستند، برای Storage باید Blaze را فعال کنید.

## 1) آماده‌سازی Flutter روی کامپیوتر
در پوشه ریشه پروژه اجرا کنید:

```bash
flutter pub get
flutter create .
```

دستور دوم فقط فایل‌های پلتفرم مثل `android/` را ایجاد می‌کند؛ فایل‌های `lib/` پروژه را از نو نمی‌سازد.

## 2) نصب FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

اگر `flutterfire` شناخته نشد، مسیر pub-cache را به PATH اضافه کنید و ترمینال را دوباره باز کنید.

## 3) ساخت پروژه Firebase
در Firebase Console یک Project بسازید.

سپس در پوشه پروژه:

```bash
firebase login
```

و برای اتصال CLI به پروژه:

```bash
firebase use --add
```

پروژه‌ای که ساختید را انتخاب کنید.

## 4) فعال‌کردن سرویس‌ها در Firebase Console

- Authentication → Sign-in method → Email/Password → Enable
- Firestore Database → Create database
- Storage → اگر عکس لازم است، پروژه را به Blaze ارتقا دهید و Storage را فعال کنید.

## 5) اتصال Flutter به Firebase

```bash
flutterfire configure
```

فقط Android را انتخاب کنید.

این دستور `lib/firebase_options.dart` را با اطلاعات واقعی پروژه جایگزین می‌کند. فایل واقعی را در GitHub عمومی قرار ندهید مگر اینکه repository خصوصی باشد و secrets/تنظیمات پروژه را درست مدیریت کرده باشید؛ در هر حال کلیدهای Firebase به‌تنهایی password نیستند، اما repository خصوصی برای پروژه شرکتی توصیه می‌شود.

## 6) Deploy قوانین و Indexها

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

## 7) اجرای تست

```bash
flutter analyze
flutter test
flutter run
```

## 8) ساخت APK

```bash
flutter build apk --release
```

فایل خروجی معمولاً در این مسیر ایجاد می‌شود:

`build/app/outputs/flutter-apk/app-release.apk`

## ترتیب پیشنهادی

ZIP اصلاح‌شده → GitHub خصوصی → Firebase → flutterfire configure → Deploy Rules/Indexes → ساخت کاربر مدیر → تست ورود → ساخت پروژه آزمایشی → تست ثبت پیشرفت → تست عکس → تست گزارش → APK نهایی
