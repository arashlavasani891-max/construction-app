import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/jalali_date.dart';
import '../application/workforce_providers.dart';
import '../domain/workforce_models.dart';

class WorkforceEntryScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String projectName;

  const WorkforceEntryScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  ConsumerState<WorkforceEntryScreen> createState() =>
      _WorkforceEntryScreenState();
}

class _WorkforceEntryScreenState extends ConsumerState<WorkforceEntryScreen> {
  Contractor? _contractor;
  final _activityController = TextEditingController();
  final _skilledController = TextEditingController(text: '0');
  final _laborController = TextEditingController(text: '0');
  final _descriptionController = TextEditingController();

  int get _skilled => int.tryParse(_skilledController.text) ?? 0;
  int get _labor => int.tryParse(_laborController.text) ?? 0;
  int get _total => _skilled + _labor;

  @override
  Widget build(BuildContext context) {
    final contractorsAsync = ref.watch(contractorsProvider);
    final entryState = ref.watch(workforceEntryControllerProvider);
    final todayAsync = ref.watch(todayWorkforceProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(title: const Text('استقرار نفرات پیمانکاران')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('پروژه: ${widget.projectName}',
              style: Theme.of(context).textTheme.titleMedium),
          Text('تاریخ: ${JalaliDate.display(_todayTimestamp())}'),
          const SizedBox(height: 16),
          contractorsAsync.when(
            data: (contractors) => DropdownButtonFormField<Contractor>(
              value: _contractor,
              decoration: const InputDecoration(labelText: 'نام پیمانکار'),
              items: contractors
                  .where((c) => c.active)
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _contractor = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('خطا: $e'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _activityController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'شرح فعالیت'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _skilledController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'استادکار'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _laborController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'کارگر'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('مجموع نفرات: $_total',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: entryState.isLoading ? null : _submit,
            child: entryState.isLoading
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('ثبت'),
          ),
          const Divider(height: 32),
          Text('ثبت‌های امروز', style: Theme.of(context).textTheme.titleMedium),
          todayAsync.when(
            data: (records) => Column(
              children: records
                  .map((r) => ListTile(
                        title: Text('${r.contractorName} — ${r.activityDescription}'),
                        subtitle: Text(
                            'استادکار: ${r.skilledCount}  |  کارگر: ${r.laborCount}  |  مجموع: ${r.totalCount}'),
                        trailing: Text(r.createdByUsername),
                      ))
                  .toList(),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('خطا: $e'),
          ),
        ],
      ),
    );
  }

  Timestamp _todayTimestamp() {
    // فقط برای نمایش امروز به شمسی؛ ثبت واقعی از FieldValue.serverTimestamp
    // در ریپازیتوری استفاده می‌کند، نه این مقدار محلی.
    return Timestamp.fromDate(DateTime.now());
  }

  Future<void> _submit() async {
    if (_contractor == null || _activityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پیمانکار و شرح فعالیت را وارد کنید.')),
      );
      return;
    }
    final success = await ref.read(workforceEntryControllerProvider.notifier).submit(
          projectId: widget.projectId,
          contractorId: _contractor!.id,
          contractorName: _contractor!.name,
          activityDescription: _activityController.text.trim(),
          skilledCount: _skilled,
          laborCount: _labor,
          description: _descriptionController.text.trim(),
        );
    if (success && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ثبت شد.')));
      setState(() {
        _activityController.clear();
        _skilledController.text = '0';
        _laborController.text = '0';
        _descriptionController.clear();
      });
    }
  }
}
