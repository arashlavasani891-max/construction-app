import 'package:flutter/material.dart';

/// نمای گرافیکی سریع وضعیت پروژه (بند ۲۶) — سبز/زرد/قرمز بر اساس درصد.
class ProgressHeatmap extends StatelessWidget {
  final Map<String, double> progressByLabel; // نام نمایشی → درصد
  final String title;

  const ProgressHeatmap({
    super.key,
    required this.progressByLabel,
    required this.title,
  });

  Color _colorFor(double percent) {
    if (percent >= 80) return Colors.green;
    if (percent >= 50) return Colors.amber;
    if (percent > 0) return Colors.orange;
    return Colors.red.shade200;
  }

  @override
  Widget build(BuildContext context) {
    final entries = progressByLabel.entries.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Text('هنوز داده‌ای برای این تاریخ ثبت نشده است.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entries
                    .map((e) => Container(
                          width: 84,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _colorFor(e.value),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                e.key,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${e.value.toStringAsFixed(0)}٪',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
