import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

import '../../reports/domain/report_models.dart';

/// خروجی Excel گزارش پیشرفت (بند ۲۹). برای نگه‌داشتن دامنه این فاز
/// مدیریت‌پذیر، مهم‌ترین گزارش‌ها (پیشرفت کل/رشته/بلوک/طبقه) پیاده‌سازی
/// شده‌اند؛ همین الگو برای گزارش‌های دیگر بند ۲۹ (پیمانکاران، کاربران، ...)
/// با افزودن یک Sheet مشابه قابل تکرار است.
class ExcelExportService {
  Future<File> exportProgressReport({
    required String projectName,
    required ProjectReportSnapshot snapshot,
    required Map<String, String> blockNames,
    required Map<String, String> floorNames,
    required Map<String, String> categoryNames,
  }) async {
    final workbook = Excel.createExcel();
    final sheet = workbook['گزارش پیشرفت'];
    workbook.delete('Sheet1');

    sheet.appendRow([TextCellValue('گزارش پیشرفت پروژه: $projectName')]);
    sheet.appendRow([
      TextCellValue('تاریخ گزارش:'),
      TextCellValue(_formatDate(snapshot.asOf)),
    ]);
    sheet.appendRow([]);

    sheet.appendRow([
      TextCellValue('پیشرفت کل پروژه'),
      TextCellValue('${snapshot.overallProgress.toStringAsFixed(1)}٪'),
    ]);
    sheet.appendRow([]);

    sheet.appendRow([TextCellValue('پیشرفت به تفکیک رشته')]);
    for (final entry in snapshot.progressByCategory.entries) {
      sheet.appendRow([
        TextCellValue(categoryNames[entry.key] ?? entry.key),
        TextCellValue('${entry.value.toStringAsFixed(1)}٪'),
      ]);
    }
    sheet.appendRow([]);

    sheet.appendRow([TextCellValue('پیشرفت به تفکیک بلوک')]);
    for (final entry in snapshot.progressByBlock.entries) {
      sheet.appendRow([
        TextCellValue(blockNames[entry.key] ?? entry.key),
        TextCellValue('${entry.value.toStringAsFixed(1)}٪'),
      ]);
    }
    sheet.appendRow([]);

    sheet.appendRow([TextCellValue('پیشرفت به تفکیک طبقه')]);
    for (final entry in snapshot.progressByFloor.entries) {
      sheet.appendRow([
        TextCellValue(floorNames[entry.key] ?? entry.key),
        TextCellValue('${entry.value.toStringAsFixed(1)}٪'),
      ]);
    }

    final bytes = workbook.encode()!;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/progress_report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await file.writeAsBytes(bytes);
    return file;
  }

  String _formatDate(DateTime d) => '${d.year}-${d.month}-${d.day}';
}
