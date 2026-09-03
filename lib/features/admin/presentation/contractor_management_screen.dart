import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workforce/application/workforce_providers.dart';
import '../../workforce/domain/workforce_models.dart';

class ContractorManagementScreen extends ConsumerWidget {
  const ContractorManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contractorsAsync = ref.watch(contractorsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('مدیریت پیمانکاران')),
      body: contractorsAsync.when(
        data: (contractors) => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: contractors.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final c = contractors[index];
            return ListTile(
              title: Text(c.name),
              subtitle: Text('کد: ${c.code} — نوع فعالیت: ${c.activityType}'),
              trailing: Switch(
                value: c.active,
                onChanged: (v) => ref
                    .read(workforceRepositoryProvider)
                    .setContractorActive(c.id, v),
              ),
              onTap: () => _editDialog(context, ref, contractor: c),
              onLongPress: () => _deleteConfirm(context, ref, c),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطا: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('پیمانکار جدید'),
      ),
    );
  }

  Future<void> _editDialog(BuildContext context, WidgetRef ref,
      {Contractor? contractor}) async {
    final nameController = TextEditingController(text: contractor?.name);
    final codeController = TextEditingController(text: contractor?.code);
    final typeController = TextEditingController(text: contractor?.activityType);
    final descController = TextEditingController(text: contractor?.description);

    final save = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(contractor == null ? 'پیمانکار جدید' : 'ویرایش پیمانکار'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'نام')),
              TextField(
                  controller: codeController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'کد')),
              TextField(
                  controller: typeController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'نوع فعالیت')),
              TextField(
                  controller: descController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'توضیحات')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ذخیره')),
        ],
      ),
    );

    if (save == true && nameController.text.trim().isNotEmpty) {
      final repo = ref.read(workforceRepositoryProvider);
      final data = Contractor(
        id: contractor?.id ?? '',
        name: nameController.text.trim(),
        code: codeController.text.trim(),
        activityType: typeController.text.trim(),
        description: descController.text.trim(),
        active: contractor?.active ?? true,
      );
      if (contractor == null) {
        await repo.addContractor(data);
      } else {
        await repo.updateContractor(data);
      }
    }
  }

  Future<void> _deleteConfirm(
      BuildContext context, WidgetRef ref, Contractor c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text('پیمانکار «${c.name}» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(workforceRepositoryProvider).deleteContractor(c.id);
    }
  }
}
