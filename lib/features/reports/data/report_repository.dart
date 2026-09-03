import '../../checklist/data/checklist_repository.dart';
import '../../checklist/domain/checklist_models.dart';
import '../../progress/data/progress_repository.dart';
import '../../progress/domain/progress_record.dart';
import '../domain/report_models.dart';

class ReportRepository {
  final ProgressRepository _progressRepository;
  final ChecklistRepository _checklistRepository;

  ReportRepository({
    ProgressRepository? progressRepository,
    ChecklistRepository? checklistRepository,
  })  : _progressRepository = progressRepository ?? ProgressRepository(),
        _checklistRepository = checklistRepository ?? ChecklistRepository();

  /// قانون اصلی بند ۱۴: برای هر فعالیت/مکان،
  /// «آخرین رکورد با createdAt <= asOf» وضعیت آن را مشخص می‌کند.
  ///
  /// چون Firestore نمی‌تواند «جدیدترین به‌ازای هر گروه» را در یک Query
  /// بدهد، همه رکوردهای تا آن تاریخ خوانده می‌شوند (allRecordsUpTo، که
  /// already ordered by createdAt desc) و اولین باری که یک کلید
  /// (item+block+floor+unit) دیده می‌شود همان جدیدترین آن است.
  Future<ProjectReportSnapshot> computeReport({
    required String projectId,
    required DateTime asOf,
  }) async {
    final records = await _progressRepository.allRecordsUpTo(
      projectId: projectId,
      asOf: asOf,
    );

    final latestByKey = <String, ProgressRecord>{};
    for (final r in records) {
      final key = '${r.checklistItemId}_${r.blockId}_${r.floorId}_${r.unitId ?? ''}';
      // چون records نزولی مرتب است، اولین برخورد = جدیدترین
      latestByKey.putIfAbsent(key, () => r);
    }
    final latestRecords = latestByKey.values.toList();

    // --- وزن فعالیت‌ها (بند ۲۸) ---
    final categories = await _checklistRepository.streamCategories().first;
    final itemsByCategory = <String, List<ChecklistItem>>{};
    final allItems = <ChecklistItem>[];
    for (final cat in categories) {
      final items = await _checklistRepository.streamItemsOfCategory(cat.id).first;
      itemsByCategory[cat.id] = items;
      allItems.addAll(items);
    }
    final weightByItem = {for (final i in allItems) i.id: i.weight};

    // میانگین درصد هر فعالیت در همه مکان‌ها (بند ۲۸ روی سطح فعالیت اعمال می‌شود)
    final percentsByItem = <String, List<double>>{};
    for (final r in latestRecords) {
      percentsByItem.putIfAbsent(r.checklistItemId, () => []).add(r.progressPercent);
    }
    final avgPercentByItem = {
      for (final entry in percentsByItem.entries)
        entry.key: entry.value.reduce((a, b) => a + b) / entry.value.length
    };

    final overallProgress = _weightedAverage(avgPercentByItem, weightByItem);

    final progressByCategory = <String, double>{};
    for (final cat in categories) {
      final itemIds = (itemsByCategory[cat.id] ?? []).map((i) => i.id).toSet();
      final subset = {
        for (final e in avgPercentByItem.entries)
          if (itemIds.contains(e.key)) e.key: e.value
      };
      progressByCategory[cat.id] = _weightedAverage(subset, weightByItem);
    }

    // --- تجمیع در سطح بلوک/طبقه/واحد (میانگین ساده رکوردهای همان سطح) ---
    final progressByBlock = _averageByKey(latestRecords, (r) => r.blockId);
    final progressByFloor = _averageByKey(latestRecords, (r) => r.floorId);
    final progressByUnit = _averageByKey(
      latestRecords.where((r) => r.unitId != null),
      (r) => r.unitId!,
    );

    final completed = latestRecords.where((r) => r.progressPercent >= 100).length;
    final notStarted = latestRecords.where((r) => r.progressPercent <= 0).length;
    final inProgress = latestRecords.length - completed - notStarted;

    return ProjectReportSnapshot(
      asOf: asOf,
      overallProgress: overallProgress,
      progressByCategory: progressByCategory,
      progressByBlock: progressByBlock,
      progressByFloor: progressByFloor,
      progressByUnit: progressByUnit,
      totalActivitiesTracked: latestRecords.length,
      completedActivities: completed,
      inProgressActivities: inProgress,
      notStartedActivities: notStarted,
    );
  }

  /// روند پیشرفت کل پروژه در چند تاریخ منتخب (بند ۱۶) — برای نمودار روند.
  /// نمونه‌برداری هفتگی بین اولین رکورد و امروز انجام می‌شود.
  Future<List<ProgressTrendPoint>> computeTrend({
    required String projectId,
    int sampleCount = 8,
  }) async {
    final all = await _progressRepository.allRecords(projectId);
    if (all.isEmpty) return [];

    final firstDate = all.first.createdAt.toDate();
    final lastDate = DateTime.now();
    final totalDays = lastDate.difference(firstDate).inDays.clamp(1, 100000);
    final step = (totalDays / (sampleCount - 1)).ceil().clamp(1, totalDays);

    final points = <ProgressTrendPoint>[];
    for (var i = 0; i < sampleCount; i++) {
      final date = firstDate.add(Duration(days: step * i));
      final asOf = date.isAfter(lastDate) ? lastDate : date;
      final snapshot = await computeReport(projectId: projectId, asOf: asOf);
      points.add(ProgressTrendPoint(asOf, snapshot.overallProgress));
      if (!asOf.isBefore(lastDate)) break;
    }
    return points;
  }

  double _weightedAverage(
      Map<String, double> percentByItem, Map<String, double> weightByItem) {
    double weightedSum = 0;
    double weightTotal = 0;
    for (final entry in percentByItem.entries) {
      final w = weightByItem[entry.key] ?? 0;
      if (w > 0) {
        weightedSum += entry.value * w;
        weightTotal += w;
      }
    }
    if (weightTotal > 0) return weightedSum / weightTotal;

    // اگر هیچ وزنی تعریف نشده (مدیر هنوز وزن‌گذاری نکرده)، میانگین ساده
    // به‌عنوان مقدار پیش‌فرض معقول برگردانده می‌شود.
    if (percentByItem.isEmpty) return 0;
    return percentByItem.values.reduce((a, b) => a + b) / percentByItem.length;
  }

  Map<String, double> _averageByKey(
      Iterable<ProgressRecord> records, String Function(ProgressRecord) keyOf) {
    final sums = <String, double>{};
    final counts = <String, int>{};
    for (final r in records) {
      final key = keyOf(r);
      sums[key] = (sums[key] ?? 0) + r.progressPercent;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return {for (final key in sums.keys) key: sums[key]! / counts[key]!};
  }
}
