import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../checklist/application/checklist_providers.dart';
import '../../projects/application/project_providers.dart';
import '../../reports/application/report_providers.dart';
import '../data/excel_export_service.dart';
import '../data/pdf_export_service.dart';

class ExportCenterScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String projectName;

  const ExportCenterScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  ConsumerState<ExportCenterScreen> createState() => _ExportCenterScreenState();
}

class _ExportCenterScreenState extends ConsumerState<ExportCenterScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('خروجی گزارش‌ها')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'خروجی بر اساس تاریخ گزارش انتخاب‌شده در داشبورد تولید می‌شود.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _busy ? null : _exportExcel,
              icon: const Icon(Icons.grid_on),
              label: const Text('خروجی Excel (گزارش پیشرفت)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _busy ? null : _exportPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('خروجی PDF (گزارش مدیریتی)'),
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _exportExcel() async {
    setState(() => _busy = true);
    try {
      final snapshot = await ref.read(reportSnapshotProvider(widget.projectId).future);
      final blockNames = await ref.read(blockNamesProvider(widget.projectId).future);
      final floorNames = await ref.read(floorNamesProvider(widget.projectId).future);
      final categories = await ref.read(checklistCategoriesProvider.future);
      final categoryNames = {for (final c in categories) c.id: c.name};

      final file = await ExcelExportService().exportProgressReport(
        projectName: widget.projectName,
        snapshot: snapshot,
        blockNames: blockNames,
        floorNames: floorNames,
        categoryNames: categoryNames,
      );
      await Share.shareXFiles([XFile(file.path)], text: 'گزارش پیشرفت — ${widget.projectName}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _busy = true);
    try {
      final snapshot = await ref.read(reportSnapshotProvider(widget.projectId).future);
      final blockNames = await ref.read(blockNamesProvider(widget.projectId).future);
      final floorNames = await ref.read(floorNamesProvider(widget.projectId).future);
      final categories = await ref.read(checklistCategoriesProvider.future);
      final categoryNames = {for (final c in categories) c.id: c.name};

      final file = await PdfExportService().exportManagementReport(
        projectName: widget.projectName,
        snapshot: snapshot,
        blockNames: blockNames,
        floorNames: floorNames,
        categoryNames: categoryNames,
      );
      await Printing.layoutPdf(onLayout: (_) => file.readAsBytes());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
