import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../checklist/application/checklist_providers.dart';
import '../../checklist/domain/checklist_models.dart';
import '../../projects/application/project_providers.dart';
import '../../projects/domain/project.dart';
import '../application/progress_providers.dart';
import 'progress_history_screen.dart';

/// صفحه ثبت پیشرفت برای کاربر اجرایی — طبق بند ۳۴: باید بسیار ساده
/// و سریع باشد. کاربر فقط دسته چک‌لیست مربوط به نقش خودش را می‌بیند.
class ProgressEntryScreen extends ConsumerStatefulWidget {
  final String projectId;
  final ChecklistCategory category;

  const ProgressEntryScreen({
    super.key,
    required this.projectId,
    required this.category,
  });

  @override
  ConsumerState<ProgressEntryScreen> createState() =>
      _ProgressEntryScreenState();
}

class _ProgressEntryScreenState extends ConsumerState<ProgressEntryScreen> {
  ChecklistItem? _selectedItem;
  Block? _selectedBlock;
  Floor? _selectedFloor;
  Unit? _selectedUnit; // اختیاری — بعضی فعالیت‌ها سطح واحد ندارند
  double _percent = 0;
  final _descriptionController = TextEditingController();
  File? _photo;

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(checklistItemsProvider(widget.category.id));
    final blocksAsync = ref.watch(blocksOfProjectProvider(widget.projectId));
    final entryState = ref.watch(progressEntryControllerProvider);
    final isSaving = entryState.isLoading;

    return Scaffold(
      appBar: AppBar(title: Text('ثبت پیشرفت — ${widget.category.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          itemsAsync.when(
            data: (items) => DropdownButtonFormField<ChecklistItem>(
              value: _selectedItem,
              decoration: const InputDecoration(labelText: 'فعالیت'),
              items: items
                  .map((i) => DropdownMenuItem(value: i, child: Text(i.name)))
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedItem = v;
                if (v != null) {
                }
              }),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('خطا: $e'),
          ),
          const SizedBox(height: 12),
          blocksAsync.when(
            data: (blocks) => DropdownButtonFormField<Block>(
              value: _selectedBlock,
              decoration: const InputDecoration(labelText: 'بلوک'),
              items: blocks
                  .map((b) => DropdownMenuItem(value: b, child: Text(b.name)))
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedBlock = v;
                _selectedFloor = null;
                _selectedUnit = null;
              }),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('خطا: $e'),
          ),
          const SizedBox(height: 12),
          if (_selectedBlock != null)
            Consumer(builder: (context, ref, _) {
              final floorsAsync =
                  ref.watch(floorsOfBlockProvider(_selectedBlock!.id));
              return floorsAsync.when(
                data: (floors) => DropdownButtonFormField<Floor>(
                  value: _selectedFloor,
                  decoration: const InputDecoration(labelText: 'طبقه'),
                  items: floors
                      .map((f) =>
                          DropdownMenuItem(value: f, child: Text(f.name)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _selectedFloor = v;
                    _selectedUnit = null;
                  }),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('خطا: $e'),
              );
            }),
          const SizedBox(height: 12),
          if (_selectedFloor != null && _selectedFloor!.unitsCount > 0)
            Consumer(builder: (context, ref, _) {
              final unitsAsync =
                  ref.watch(unitsOfFloorProvider(_selectedFloor!.id));
              return unitsAsync.when(
                data: (units) => DropdownButtonFormField<Unit>(
                  value: _selectedUnit,
                  decoration: const InputDecoration(labelText: 'واحد (اختیاری)'),
                  items: units
                      .map((u) =>
                          DropdownMenuItem(value: u, child: Text(u.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedUnit = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('خطا: $e'),
              );
            }),
          const SizedBox(height: 24),
          Text('درصد پیشرفت: ${_percent.toStringAsFixed(0)}٪',
              style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: _percent,
            min: 0,
            max: 100,
            divisions: 100,
            label: '${_percent.toStringAsFixed(0)}٪',
            onChanged: (v) => setState(() => _percent = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_photo != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_photo!, height: 64, width: 64, fit: BoxFit.cover),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(_photo == null ? 'افزودن عکس (اختیاری)' : 'تغییر عکس'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_selectedItem != null &&
              _selectedBlock != null &&
              _selectedFloor != null)
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProgressHistoryScreen(
                  itemName: _selectedItem!.name,
                  checklistItemId: _selectedItem!.id,
                  blockId: _selectedBlock!.id,
                  floorId: _selectedFloor!.id,
                  unitId: _selectedUnit?.id,
                ),
              )),
              icon: const Icon(Icons.history),
              label: const Text('مشاهده تاریخچه این فعالیت'),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: isSaving ? null : _submit,
            child: isSaving
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('ثبت'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (file != null) setState(() => _photo = File(file.path));
  }

  Future<void> _submit() async {
    if (_selectedItem == null || _selectedBlock == null || _selectedFloor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فعالیت، بلوک و طبقه را انتخاب کنید.')),
      );
      return;
    }

    final success = await ref.read(progressEntryControllerProvider.notifier).submit(
          projectId: widget.projectId,
          blockId: _selectedBlock!.id,
          floorId: _selectedFloor!.id,
          unitId: _selectedUnit?.id,
          checklistCategoryId: widget.category.id,
          checklistItemId: _selectedItem!.id,
          progressPercent: _percent,
          description: _descriptionController.text.trim(),
          photo: _photo,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('پیشرفت ثبت شد.')));
      setState(() {
        _percent = 0;
        _descriptionController.clear();
        _photo = null;
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ثبت ناموفق بود.')));
    }
  }
}
