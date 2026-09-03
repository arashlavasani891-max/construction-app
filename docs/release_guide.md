# راهنمای Build و انتشار Android (فاز ۱۳)

## گام ۰ — تولید پوشه‌های native (فقط یک‌بار)

این پروژه فقط شامل `lib/` و `pubspec.yaml` است (چون در این محیط چت امکان اجرای
ابزار رسمی Flutter برای تولید پوشه‌های `android/`, `ios/` و غیره وجود نداشت).
پیش از هر کار دیگری، روی سیستم خودتان این را اجرا کنید:

```
cd construction_app
flutter create .
```

این دستور روی یک پروژه موجود، فقط پوشه‌های پلتفرم (android/ios/...) را اضافه
می‌کند و به `lib/` یا `pubspec.yaml` شما دست نمی‌زند.

## گام ۱ — تنظیم Application ID

در `android/app/build.gradle`، مقدار `applicationId` را به چیزی یکتا مثل
`com.yourcompany.constructioncontrol` تغییر دهید (پیش‌فرض Flutter مناسب
انتشار نیست).

## گام ۲ — آیکون و نام اپ

- نام نمایشی در `android/app/src/main/AndroidManifest.xml` → `android:label`
- آیکون با پکیج `flutter_launcher_icons` قابل تولید خودکار از یک PNG است.

## گام ۳ — Keystore برای امضای نسخه انتشار

```
keytool -genkey -v -keystore ~/construction-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias construction
```

سپس `android/key.properties` بسازید (این فایل نباید Commit شود):

```
storePassword=<رمز شما>
keyPassword=<رمز شما>
keyAlias=construction
storeFile=/مسیر/کامل/construction-release-key.jks
```

و در `android/app/build.gradle` بخش `signingConfigs`/`buildTypes.release` را
طبق مستندات رسمی Flutter (`flutter build apk` → «Build and release an Android app»)
به این فایل وصل کنید.

## گام ۴ — Build نسخه نهایی

```
flutter build appbundle --release   # برای انتشار در Google Play (توصیه‌شده)
# یا
flutter build apk --release --split-per-abi   # برای نصب مستقیم/توزیع دستی
```

خروجی در `build/app/outputs/` قرار می‌گیرد.

## گام ۵ — بررسی نهایی قبل از انتشار

- [ ] `firestore.rules` و `storage.rules` روی پروژه Firebase واقعی Deploy شده‌اند.
- [ ] چک‌لیست `docs/testing_checklist.md` کامل انجام شده.
- [ ] `docs/security_checklist.md` بررسی شده.
- [ ] یک حساب ادمین واقعی (نه تستی) طبق راهنمای README ساخته شده.
