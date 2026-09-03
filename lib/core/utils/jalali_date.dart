import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// طبق بند ۳۱ پرامپت: در دیتابیس Timestamp استاندارد ذخیره می‌شود
/// و فقط هنگام نمایش به کاربر به شمسی تبدیل می‌شود.
class JalaliDate {
  JalaliDate._();

  /// نمایش یک Timestamp به فرمت YYYY/MM/DD شمسی
  static String display(Timestamp timestamp) {
    final gregorian = timestamp.toDate();
    final jalali = Jalali.fromDateTime(gregorian);
    return '${jalali.year}/${jalali.month.toString().padLeft(2, '0')}/'
        '${jalali.day.toString().padLeft(2, '0')}';
  }

  /// نمایش تاریخ + ساعت (مثلاً برای تاریخچه دقیق ثبت‌ها)
  static String displayWithTime(Timestamp timestamp) {
    final gregorian = timestamp.toDate();
    final jalali = Jalali.fromDateTime(gregorian);
    final hh = gregorian.hour.toString().padLeft(2, '0');
    final mm = gregorian.minute.toString().padLeft(2, '0');
    return '${display(timestamp)}  ساعت $hh:$mm';
  }

  /// تبدیل تاریخ شمسی انتخاب‌شده توسط مدیر (برای فیلتر گزارش) به
  /// انتهای همان روز میلادی، برای استفاده در Query <= createdAt
  static DateTime endOfJalaliDay(Jalali date) {
    final gregorian = date.toDateTime();
    return DateTime(gregorian.year, gregorian.month, gregorian.day, 23, 59, 59, 999);
  }
}
