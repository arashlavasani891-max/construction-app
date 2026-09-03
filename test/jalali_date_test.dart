import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:construction_control/core/utils/jalali_date.dart';

void main() {
  group('JalaliDate', () {
    test('تبدیل یک تاریخ میلادی مشخص به شمسی با فرمت YYYY/MM/DD', () {
      // ۲۲ سپتامبر ۲۰۲۶ میلادی معادل ابتدای ۱۴۰۵/۰۷/۰۱ شمسی است.
      final gregorian = DateTime(2026, 9, 22);
      final display = JalaliDate.display(Timestamp.fromDate(gregorian));
      expect(display, matches(RegExp(r'^\d{4}/\d{2}/\d{2}$')));
    });

    test('نمایش تاریخ+ساعت شامل رشته ساعت است', () {
      final gregorian = DateTime(2026, 9, 22, 14, 30);
      final display = JalaliDate.displayWithTime(Timestamp.fromDate(gregorian));
      expect(display, contains('14:30'));
    });
  });
}
