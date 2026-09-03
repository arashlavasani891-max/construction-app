import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../checklist/application/checklist_providers.dart';
import '../../projects/application/project_providers.dart';
import '../application/report_providers.dart';
import 'progress_heatmap.dart';

class ReportDashboardScreen extends ConsumerWidget {
  final String projectId;
  final String projectName;

  const ReportDashboardScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportDate = ref.watch(reportDateProvider);
    final snapshotAsync = ref.watch(reportSnapshotProvider(projectId));
    final categoriesAsync = ref.watch(checklistCategoriesProvider);
    final blockNamesAsync = ref.watch(blockNamesProvider(projectId));
    final floorNamesAsync = ref.watch(floorNamesProvider(projectId));
    final trendAsync = ref.watch(progressTrendProvider(projectId));

    return Scaffold(
      appBar: AppBar(title: Text('داشبورد — $projectName')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------- بند ۲۳: انتخاب تاریخ گزارش ----------
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('تاریخ گزارش'),
              subtitle: Text(_jalali(reportDate)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: reportDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) {
                  ref.read(reportDateProvider.notifier).state = picked;
                }
              },
            ),
          ),
          const SizedBox(height: 16),

          snapshotAsync.when(
            data: (snapshot) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------- بند ۲۴: پیشرفت کل ----------
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text('پیشرفت کل پروژه',
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            '${snapshot.overallProgress.toStringAsFixed(1)}٪',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ---------- پیشرفت هر رشته (ابنیه/مکانیک/برق) ----------
                  categoriesAsync.when(
                    data: (categories) => Row(
                      children: categories
                          .map((c) => Expanded(
                                child: _miniStat(
                                  context,
                                  c.name,
                                  snapshot.progressByCategory[c.id] ?? 0,
                                ),
                              ))
                          .toList(),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),

                  // ---------- بند ۲۴: وضعیت فعالیت‌ها ----------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('وضعیت فعالیت‌ها',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 160,
                            child: PieChart(PieChartData(sections: [
                              PieChartSectionData(
                                value: snapshot.completedActivities.toDouble(),
                                color: Colors.green,
                                title: 'انجام‌شده',
                                radius: 60,
                              ),
                              PieChartSectionData(
                                value: snapshot.inProgressActivities.toDouble(),
                                color: Colors.amber,
                                title: 'در حال اجرا',
                                radius: 60,
                              ),
                              PieChartSectionData(
                                value: snapshot.notStartedActivities.toDouble(),
                                color: Colors.red.shade200,
                                title: 'شروع‌نشده',
                                radius: 60,
                              ),
                            ])),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ---------- بند ۲۵-۲۶: بلوک‌ها و طبقات (Heatmap) ----------
                  blockNamesAsync.when(
                    data: (blockNames) => ProgressHeatmap(
                      title: 'وضعیت بلوک‌ها',
                      progressByLabel: {
                        for (final e in snapshot.progressByBlock.entries)
                          (blockNames[e.key] ?? e.key): e.value
                      },
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),
                  floorNamesAsync.when(
                    data: (floorNames) => ProgressHeatmap(
                      title: 'وضعیت طبقات',
                      progressByLabel: {
                        for (final e in snapshot.progressByFloor.entries)
                          (floorNames[e.key] ?? e.key): e.value
                      },
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),

                  // ---------- بند ۲۷: نمودار مقایسه بلوک‌ها ----------
                  blockNamesAsync.when(
                    data: (blockNames) => _barChartCard(
                      context,
                      title: 'نمودار مقایسه بلوک‌ها',
                      data: {
                        for (final e in snapshot.progressByBlock.entries)
                          (blockNames[e.key] ?? e.key): e.value
                      },
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('خطا: $e'),
          ),

          const SizedBox(height: 16),
          // ---------- بند ۱۶: نمودار روند پیشرفت در طول زمان ----------
          trendAsync.when(
            data: (points) => _trendChartCard(context, points),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _jalali(DateTime d) {
    final j = Jalali.fromDateTime(d);
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }

  Widget _miniStat(BuildContext context, String label, double value) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text('${value.toStringAsFixed(0)}٪',
                  style: Theme.of(context).textTheme.titleLarge),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );

  Widget _barChartCard(BuildContext context,
      {required String title, required Map<String, double> data}) {
    final entries = data.entries.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: entries.isEmpty
                  ? const Center(child: Text('داده‌ای موجود نیست.'))
                  : BarChart(BarChartData(
                      maxY: 100,
                      barGroups: [
                        for (var i = 0; i < entries.length; i++)
                          BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                                toY: entries[i].value, color: Colors.teal)
                          ]),
                      ],
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= entries.length) {
                                return const SizedBox.shrink();
                              }
                              return Text(entries[i].key,
                                  style: const TextStyle(fontSize: 10));
                            },
                          ),
                        ),
                      ),
                    )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendChartCard(BuildContext context, List<dynamic> points) {
    if (points.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('روند پیشرفت پروژه در طول زمان',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: LineChart(LineChartData(
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: Colors.indigo,
                    dotData: const FlDotData(show: true),
                    spots: [
                      for (var i = 0; i < points.length; i++)
                        FlSpot(i.toDouble(), points[i].overallProgress),
                    ],
                  ),
                ],
              )),
            ),
          ],
        ),
      ),
    );
  }
}
