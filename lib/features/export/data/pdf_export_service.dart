import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

import '../../reports/domain/report_models.dart';

/// خروجی PDF گزارش مدیریتی (بند ۳۰). طبق مثال پرامپت: عنوان، تاریخ گزارش،
/// پیشرفت کل/رشته‌ها، سپس جدول بلوک‌ها و طبقات. نمودارها در نسخهٔ اول به‌صورت
/// جدول ساده رندر می‌شوند؛ افزودن گراف واقعی به PDF در فاز بعد ممکن است.
class PdfExportService {
  Future<File> exportManagementReport({
    required String projectName,
    required ProjectReportSnapshot snapshot,
    required Map<String, String> blockNames,
    required Map<String, String> floorNames,
    required Map<String, String> categoryNames,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('گزارش وضعیت پروژه $projectName',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Text('تاریخ گزارش: ${_formatDate(snapshot.asOf)}'),
          pw.SizedBox(height: 12),
          pw.Text('پیشرفت کل: ${snapshot.overallProgress.toStringAsFixed(1)}٪',
              style: const pw.TextStyle(fontSize: 16)),
          pw.SizedBox(height: 16),
          pw.Text('پیشرفت به تفکیک رشته',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          _table(
            ['رشته', 'پیشرفت'],
            snapshot.progressByCategory.entries
                .map((e) => [
                      categoryNames[e.key] ?? e.key,
                      '${e.value.toStringAsFixed(1)}٪'
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('وضعیت بلوک‌ها', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          _table(
            ['بلوک', 'پیشرفت'],
            snapshot.progressByBlock.entries
                .map((e) => [
                      blockNames[e.key] ?? e.key,
                      '${e.value.toStringAsFixed(1)}٪'
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('وضعیت طبقات', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          _table(
            ['طبقه', 'پیشرفت'],
            snapshot.progressByFloor.entries
                .map((e) => [
                      floorNames[e.key] ?? e.key,
                      '${e.value.toStringAsFixed(1)}٪'
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('وضعیت فعالیت‌ها', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          _table(
            ['وضعیت', 'تعداد'],
            [
              ['انجام‌شده', '${snapshot.completedActivities}'],
              ['در حال اجرا', '${snapshot.inProgressActivities}'],
              ['شروع‌نشده', '${snapshot.notStartedActivities}'],
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/management_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  pw.Widget _table(List<String> headers, List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerDirection: pw.TextDirection.rtl,
      cellAlignment: pw.Alignment.centerRight,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    );
  }

  String _formatDate(DateTime d) => '${d.year}-${d.month}-${d.day}';
}
