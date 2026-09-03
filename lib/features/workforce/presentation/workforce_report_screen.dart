import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../core/utils/jalali_date.dart';
import '../application/workforce_providers.dart';
import '../domain/workforce_models.dart';

class WorkforceReportScreen extends ConsumerStatefulWidget {
  final String projectId;
  const WorkforceReportScreen({super.key, required this.projectId});

  @override
  ConsumerState<WorkforceReportScreen> createState() =>
      _WorkforceReportScreenState();
}

class _WorkforceReportScreenState extends ConsumerState<WorkforceReportScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  List<WorkforceRecord>? _records;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await ref.read(workforceRepositoryProvider).recordsInRange(
          projectId: widget.projectId,
          from: DateTime(_from.year, _from.month, _from.day),
          to: DateTime(_to.year, _to.month, _to.day, 23, 59, 59),
        );
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final records = _records ?? const <WorkforceRecord>[];

    final totalPerDay = <String, int>{};
    final perContractor = <String, int>{};
    final perActivity = <String, int>{};
    for (final r in records) {
      final day = JalaliDate.display(r.createdAt);
      totalPerDay[day] = (totalPerDay[day] ?? 0) + r.totalCount;
      perContractor[r.contractorName] =
          (perContractor[r.contractorName] ?? 0) + r.totalCount;
      perActivity[r.activityDescription] =
          (perActivity[r.activityDescription] ?? 0) + r.totalCount;
    }

    final dailyTotals = totalPerDay.values.toList();
    final sum = dailyTotals.fold(0, (a, b) => a + b);
    final avg = dailyTotals.isEmpty ? 0 : sum / dailyTotals.length;
    final maxDay = dailyTotals.isEmpty ? 0 : dailyTotals.reduce((a, b) => a > b ? a : b);
    final minDay = dailyTotals.isEmpty ? 0 : dailyTotals.reduce((a, b) => a < b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('گزارش استقرار نفرات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(isFrom: true),
                        child: Text('از: ${_jalali(_from)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(isFrom: false),
                        child: Text('تا: ${_jalali(_to)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.2,
                  children: [
                    _statCard('مجموع نفرات', '$sum'),
                    _statCard('میانگین روزانه', avg.toStringAsFixed(1)),
                    _statCard('بیشترین در یک روز', '$maxDay'),
                    _statCard('کمترین در یک روز', '$minDay'),
                  ],
                ),
                const SizedBox(height: 16),
                _breakdownSection('نفرات هر پیمانکار', perContractor),
                _breakdownSection('نفرات هر فعالیت', perActivity),
              ],
            ),
    );
  }

  String _jalali(DateTime d) {
    final j = Jalali.fromDateTime(d);
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => isFrom ? _from = picked : _to = picked);
      _load();
    }
  }

  Widget _statCard(String label, String value) => Card(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              Text(label),
            ],
          ),
        ),
      );

  Widget _breakdownSection(String title, Map<String, int> data) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(e.key), Text('${e.value} نفر')],
                ),
              ),
            if (entries.isEmpty) const Text('داده‌ای برای این بازه نیست.'),
          ],
        ),
      ),
    );
  }
}
