import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/jalali_date.dart';
import '../application/progress_providers.dart';

class ProgressHistoryScreen extends ConsumerWidget {
  final String itemName;
  final String checklistItemId;
  final String blockId;
  final String floorId;
  final String? unitId;

  const ProgressHistoryScreen({
    super.key,
    required this.itemName,
    required this.checklistItemId,
    required this.blockId,
    required this.floorId,
    this.unitId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(progressHistoryProvider((
      checklistItemId: checklistItemId,
      blockId: blockId,
      floorId: floorId,
      unitId: unitId,
    )));

    return Scaffold(
      appBar: AppBar(title: Text('تاریخچه — $itemName')),
      body: historyAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return const Center(child: Text('هنوز رکوردی ثبت نشده است.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: records.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = records[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text('${r.progressPercent.toStringAsFixed(0)}٪'),
                ),
                title: Text(JalaliDate.displayWithTime(r.createdAt)),
                subtitle: Text(
                  r.description.isEmpty
                      ? 'ثبت‌کننده: ${r.createdByUsername}'
                      : '${r.description}\nثبت‌کننده: ${r.createdByUsername}',
                ),
                isThreeLine: r.description.isNotEmpty,
                trailing: r.photoUrl != null
                    ? const Icon(Icons.photo_outlined)
                    : null,
                onTap: r.photoUrl == null
                    ? null
                    : () => showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            child: Image.network(r.photoUrl!),
                          ),
                        ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطا: $e')),
      ),
    );
  }
}
