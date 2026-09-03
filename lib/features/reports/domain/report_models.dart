class ProjectReportSnapshot {
  final DateTime asOf;
  final double overallProgress; // پیشرفت وزنی کل (بند ۲۸)
  final Map<String, double> progressByCategory; // categoryId → درصد
  final Map<String, double> progressByBlock; // blockId → درصد
  final Map<String, double> progressByFloor; // floorId → درصد
  final Map<String, double> progressByUnit; // unitId → درصد
  final int totalActivitiesTracked;
  final int completedActivities; // >= 100٪
  final int inProgressActivities; // 0 < x < 100
  final int notStartedActivities; // بدون رکورد یا 0٪

  const ProjectReportSnapshot({
    required this.asOf,
    required this.overallProgress,
    required this.progressByCategory,
    required this.progressByBlock,
    required this.progressByFloor,
    required this.progressByUnit,
    required this.totalActivitiesTracked,
    required this.completedActivities,
    required this.inProgressActivities,
    required this.notStartedActivities,
  });
}

class ProgressTrendPoint {
  final DateTime date;
  final double overallProgress;
  const ProgressTrendPoint(this.date, this.overallProgress);
}
