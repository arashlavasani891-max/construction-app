import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/checklist_providers.dart';
import '../domain/checklist_models.dart';

class ChecklistAdminScreen extends ConsumerWidget {
  const ChecklistAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(checklistCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('مدیریت چک‌لیست ساختمان')),
      body: categoriesAsync.when(
        data: (categories) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final category in categories)
              _CategoryTile(category: category),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _addCategoryDialog(context, ref, categories.length),
              icon: const Icon(Icons.add),
              label: const Text('افزودن دسته‌بندی جدید'),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطا: $e')),
      ),
    );
  }

  Future<void> _addCategoryDialog(
      BuildContext context, WidgetRef ref, int currentCount) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('دسته‌بندی جدید'),
        content: TextField(
          controller: controller,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(hintText: 'مثلاً: تأسیسات'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('افزودن')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref
          .read(checklistRepositoryProvider)
          .addCategory(name.trim(), currentCount);
    }
  }
}

class _CategoryTile extends ConsumerWidget {
  final ChecklistCategory category;
  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(checklistItemsProvider(category.id));

    return Card(
      child: ExpansionTile(
        title: Text(category.name),
        children: [
          itemsAsync.when(
            data: (items) {
              final topLevel = items.where((i) => i.isTopLevel).toList();
              return Column(
                children: [
                  for (final item in topLevel)
                    _ItemNode(item: item, allItems: items, depth: 0),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _addItemDialog(
                            context, ref, category.id, null, topLevel.length),
                        icon: const Icon(Icons.add),
                        label: const Text('افزودن فعالیت'),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Text('خطا: $e'),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'حذف دسته‌بندی',
                onPressed: () async {
                  final confirmed = await _confirm(context,
                      'دسته «${category.name}» و همه فعالیت‌های آن حذف شود؟');
                  if (confirmed) {
                    await ref
                        .read(checklistRepositoryProvider)
                        .deleteCategory(category.id);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addItemDialog(BuildContext context, WidgetRef ref,
      String categoryId, String? parentItemId, int siblingCount) async {
    final nameController = TextEditingController();
    final weightController = TextEditingController(text: '0');
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(parentItemId == null ? 'فعالیت جدید' : 'زیرمرحله جدید'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'نام فعالیت'),
            ),
            if (parentItemId == null)
              TextField(
                controller: weightController,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'وزن در پیشرفت کل (٪)'),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('افزودن')),
        ],
      ),
    );
    if (result == true && nameController.text.trim().isNotEmpty) {
      await ref.read(checklistRepositoryProvider).addItem(
            categoryId: categoryId,
            name: nameController.text.trim(),
            parentItemId: parentItemId,
            order: siblingCount,
            weight: double.tryParse(weightController.text) ?? 0,
          );
    }
  }
}

class _ItemNode extends ConsumerWidget {
  final ChecklistItem item;
  final List<ChecklistItem> allItems;
  final int depth;

  const _ItemNode({
    required this.item,
    required this.allItems,
    required this.depth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children =
        allItems.where((i) => i.parentItemId == item.id).toList();

    return Padding(
      padding: EdgeInsets.only(right: 16.0 * (depth + 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.chevron_left, size: 18),
              Expanded(
                child: Text(
                  item.weight > 0
                      ? '${item.name}  (وزن: ${item.weight.toStringAsFixed(0)}٪)'
                      : item.name,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _renameDialog(context, ref, item),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'افزودن زیرمرحله',
                onPressed: () => _addChildDialog(context, ref, item, children.length),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                onPressed: () async {
                  final confirmed =
                      await _confirm(context, 'فعالیت «${item.name}» حذف شود؟');
                  if (confirmed) {
                    await ref.read(checklistRepositoryProvider).deleteItem(item.id);
                  }
                },
              ),
            ],
          ),
          for (final child in children)
            _ItemNode(item: child, allItems: allItems, depth: depth + 1),
        ],
      ),
    );
  }

  Future<void> _renameDialog(
      BuildContext context, WidgetRef ref, ChecklistItem item) async {
    final controller = TextEditingController(text: item.name);
    final weightController =
        TextEditingController(text: item.weight.toStringAsFixed(0));
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ویرایش فعالیت'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'نام فعالیت'),
            ),
            if (item.isTopLevel)
              TextField(
                controller: weightController,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'وزن (٪)'),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ذخیره')),
        ],
      ),
    );
    if (result == true) {
      await ref.read(checklistRepositoryProvider).updateItem(ChecklistItem(
            id: item.id,
            categoryId: item.categoryId,
            parentItemId: item.parentItemId,
            name: controller.text.trim(),
            order: item.order,
            weight: double.tryParse(weightController.text) ?? item.weight,
          ));
    }
  }

  Future<void> _addChildDialog(BuildContext context, WidgetRef ref,
      ChecklistItem parent, int siblingCount) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('زیرمرحله جدید'),
        content: TextField(
          controller: controller,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(hintText: 'مثلاً: فاز ۱'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('افزودن')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(checklistRepositoryProvider).addItem(
            categoryId: parent.categoryId,
            name: name.trim(),
            parentItemId: parent.id,
            order: siblingCount,
          );
    }
  }
}

Future<bool> _confirm(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف')),
      ],
    ),
  );
  return result ?? false;
}
