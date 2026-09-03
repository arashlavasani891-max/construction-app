# خلاصه امنیت (بند ۳۲، فاز ۱۱)

اصل رعایت‌شده در کل پروژه: **UI فقط مخفی می‌کند، Firestore Rules واقعاً مسدود می‌کند.**

## چه چیزی در Rules (`firestore.rules`) enforce شده

| نگرانی | راه‌حل |
|---|---|
| مسئول برق نتواند اطلاعات ابنیه را بخواند/بنویسد | `hasChecklistAccess()` روی نوشتن `progressRecords` بر اساس `assignedChecklistCategoryIds` کاربر |
| کاربر نتواند به پروژه‌های دیگر دسترسی داشته باشد | `hasProjectAccess()` روی خواندن/نوشتن هر مجموعه‌ای که `projectId` دارد |
| کاربر نتواند تاریخ ثبت را جعل کند | `request.resource.data.createdAt == request.time` |
| کاربر نتواند ثبت‌کننده را جعل کند | `request.resource.data.createdBy == request.auth.uid` |
| تاریخچه Overwrite/حذف نشود | `allow update, delete: if false` روی `progressRecords` و `workforceRecords` |
| فقط مدیر بتواند ساختار/چک‌لیست/کاربران/پیمانکاران را تغییر دهد | `isAdmin()` بر پایه `roleId` سند `users/{uid}` |
| کاربر غیرفعال‌شده نتواند وارد شود | بررسی `active` در `AuthRepository.signInWithUsername` (لایه کلاینت) — **توصیه**: برای enforcement کامل، در آینده یک Rule اضافه شود که خواندن/نوشتن را برای کاربران با `active == false` هم مسدود کند |

## محدودیت شناخته‌شده (به‌خاطر تصمیم «کاملاً رایگان، بدون Cloud Functions»)

- ساخت/حذف واقعی حساب Firebase Auth یک کاربر دیگر از کلاینت به‌طور کامل ممکن نیست
  (نیازمند Admin SDK است که فقط در Cloud Functions یا سرور جداگانه در دسترس است).
  در این نسخه:
  - ساخت کاربر با یک نمونه موقت FirebaseApp انجام می‌شود (`UserAdminRepository`).
  - «حذف» کاربر عملاً یعنی حذف سند Firestore او (از دسترسی خارج می‌شود) نه حذف کامل حساب Auth.
  - اگر در آینده Blaze فعال شد، این محدودیت با یک Cloud Function ساده کاملاً برطرف می‌شود.

## پیش از انتشار نهایی

- [ ] `firestore.rules` را با `firebase deploy --only firestore:rules` روی پروژه واقعی اعمال کنید.
- [ ] در Firebase Console → Firestore → Rules Playground، حداقل یک سناریوی رد دسترسی (کاربر بدون assignedProjectIds که سعی در خواندن `progressRecords` پروژه دیگر دارد) را تست کنید.
- [ ] Storage Rules را هم مشابه Firestore محدود کنید (در این فاز پیش‌فرض `firebase_storage` بدون Rule سفارشی رها شده — قبل از انتشار باید `storage.rules` مشابه بند بالا نوشته شود تا فقط کاربران دارای دسترسی پروژه بتوانند عکس آپلود/دانلود کنند).
