import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/report_repository.dart';
import '../domain/report_models.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository();
});

/// تاریخ گزارش انتخاب‌شده توسط مدیر — پیش‌فرض: امروز (بند ۲۳)
final reportDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final reportSnapshotProvider =
    FutureProvider.family<ProjectReportSnapshot, String>((ref, projectId) {
  final asOf = ref.watch(reportDateProvider);
  return ref.watch(reportRepositoryProvider).computeReport(
        projectId: projectId,
        asOf: DateTime(asOf.year, asOf.month, asOf.day, 23, 59, 59),
      );
});

final progressTrendProvider =
    FutureProvider.family<List<ProgressTrendPoint>, String>((ref, projectId) {
  return ref.watch(reportRepositoryProvider).computeTrend(projectId: projectId);
});
