# کنترل پروژه ساختمان — راهنمای کامل

## وضعیت فازها (بند ۴۰ پرامپت اصلی)

| فاز | عنوان | وضعیت |
|---|---|---|
| ۱ | معماری و دیتابیس | ✅ |
| ۲ | Authentication و کاربران | ✅ |
| ۳ | ساخت پروژه و ساختار بلوک/طبقه/واحد | ✅ |
| ۴ | چک‌لیست Dynamic (درختی + وزن) | ✅ |
| ۵ | ثبت Progress و تاریخچه | ✅ |
| ۶ | سیستم استقرار نفرات | ✅ |
| ۷ | پنل کنترل پروژه (کاربران/پیمانکاران) | ✅ |
| ۸ | Dashboard و نمودارها | ✅ |
| ۹ | گزارش‌گیری بر اساس تاریخ | ✅ (موتور اصلی در ReportRepository) |
| ۱۰ | Export Excel/PDF | ✅ (گزارش پیشرفت — قابل تعمیم به سایر گزارش‌های بند ۲۹) |
| ۱۱ | امنیت و Permissionها | ✅ (Firestore + Storage Rules) — نگاه کنید به `docs/security_checklist.md` |
| ۱۲ | تست کامل | ⚠️ چک‌لیست دستی + چند Unit Test آماده است، اما اجرای واقعی روی دستگاه/Firebase انجام نشده |
| ۱۳ | Build و انتشار Android | ⚠️ راهنمای کامل آماده است؛ Build واقعی باید روی سیستم شما انجام شود |

## ⚠️ محدودیت‌های این محیط (مهم، حتماً بخوانید)

این کد در یک محیط چت بدون اتصال اینترنت و بدون Flutter SDK نصب‌شده نوشته شده. یعنی:

1. **هرگز اجرا/کامپایل نشده.** ممکن است غلط‌های تایپی جزئی یا ناسازگاری نسخه پکیج وجود داشته باشد که فقط با `flutter analyze` / `flutter run` واقعی مشخص می‌شود.
2. **پوشه‌های native (`android/`, `ios/`) وجود ندارند.** باید `flutter create .` را طبق `docs/release_guide.md` اجرا کنید.
3. **به هیچ پروژه Firebase واقعی وصل نیست.** `lib/firebase_options.dart` فقط Placeholder است.
4. تست‌های بند ۴۱ باید واقعاً روی یک دستگاه اجرا شوند — این‌جا فقط چک‌لیست و چند Unit Test منطقی (بدون نیاز به Firebase) آماده شده.

**توصیه:** این کد را به‌عنوان یک نسخه کامل و معماری‌شدهٔ اولیه (First Working Draft) در نظر بگیرید که برای رسیدن به حالت Production نیاز به یک دور Review/Debug واقعی توسط یک توسعه‌دهنده Flutter روی سیستم خودتان دارد — دقیقاً همان‌طور که بند ۴۲ پرامپت اصلی هم پیش‌بینی کرده بود (پیاده‌سازی مرحله‌ای و تست هر مرحله).

## راه‌اندازی اولیه

```
cd construction_app
flutter create .              # تولید پوشه‌های native — یک‌بار
flutter pub get
dart pub global activate flutterfire_cli
flutterfire configure         # اتصال به پروژه Firebase واقعی شما
firebase deploy --only firestore:rules,storage
flutter run
```

جزئیات کامل هر مرحله (ساخت پروژه Firebase، اولین کاربر ادمین، Signing، Build نهایی) در:
- `docs/release_guide.md`
- `docs/security_checklist.md`
- `docs/testing_checklist.md`
- `architecture.md` (سند معماری کامل، جداگانه ارسال شده)

## ایجاد اولین کاربر مدیر

تا قبل از استفاده از پنل «کاربران» (که نیاز به یک ادمین موجود دارد)، اولین
ادمین باید دستی در Firebase Console ساخته شود:

1. Authentication → یک کاربر با Email دلخواه (مثلاً `admin@construction.local`) بسازید و UID را کپی کنید.
2. Firestore:
   - `users/<UID>`: `{ username: "admin", displayName: "مدیر سیستم", roleId: "admin", active: true, assignedProjectIds: [], assignedChecklistCategoryIds: [] }`
   - `usernames/admin`: `{ email: "admin@construction.local", uid: "<UID>" }`
3. در اپ با نام‌کاربری `admin` وارد شوید.

از این پس، کاربران بعدی از داخل پنل مدیریت («کاربران» → «کاربر جدید») ساخته می‌شوند.

## نکات معماری کلیدی

- `progressRecords` و `workforceRecords` **Append-Only** هستند (بند ۱۳، ۳۷) — Rules هرگونه Update/Delete را رد می‌کند.
- `createdAt`/`createdBy` همیشه سمت سرور enforce می‌شوند (بند ۱۰).
- گزارش تاریخی (بند ۱۴) با قانون «آخرین رکورد با تاریخ <= تاریخ گزارش» در `ReportRepository.computeReport` پیاده شده — بدون Cloud Functions، چون تصمیم شما «کاملاً رایگان» بود.
- همه صفحات کلیدی از Firestore Realtime Listeners استفاده می‌کنند (تصمیم «اطلاعات لحظه‌ای»).
- هیچ ساختاری (پروژه/بلوک/طبقه/واحد/چک‌لیست/کاربر/پیمانکار/وزن) Hard-code نیست — همه از پنل مدیریت قابل تعریف است (بند ۳۵).
