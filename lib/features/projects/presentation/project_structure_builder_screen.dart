import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/project_providers.dart';
import '../domain/project.dart';
import '../domain/structure_builder_input.dart';

class ProjectStructureBuilderScreen extends ConsumerStatefulWidget {
  const ProjectStructureBuilderScreen({super.key});

  @override
  ConsumerState<ProjectStructureBuilderScreen> createState() =>
      _ProjectStructureBuilderScreenState();
}

class _ProjectStructureBuilderScreenState
    extends ConsumerState<ProjectStructureBuilderScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<_BlockForm> _blocks = [_BlockForm()];

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  int get _totalFloors =>
      _blocks.fold(0, (sum, b) => sum + b.toInput().totalFloors);
  int get _totalUnits =>
      _blocks.fold(0, (sum, b) => sum + b.toInput().totalUnits);

  @override
  Widget build(BuildContext context) {
    final builderState = ref.watch(projectBuilderControllerProvider);
    final isSaving = builderState.isLoading;

    ref.listen(projectBuilderControllerProvider, (prev, next) {
      next.whenOrNull(error: (e, _) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطا: $e')));
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('ساخت پروژه جدید')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('اطلاعات پروژه'),
          TextField(
            controller: _nameController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'نام پروژه'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'کد پروژه'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)'),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          _sectionTitle('بلوک‌ها'),
          ..._blocks.asMap().entries.map(
                (entry) => _BlockEditor(
                  key: ValueKey(entry.value),
                  block: entry.value,
                  index: entry.key,
                  onRemove: _blocks.length > 1
                      ? () => setState(() => _blocks.removeAt(entry.key))
                      : null,
                  onChanged: () => setState(() {}),
                ),
              ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() => _blocks.add(_BlockForm())),
            icon: const Icon(Icons.add),
            label: const Text('افزودن بلوک'),
          ),
          const SizedBox(height: 24),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryItem('بلوک‌ها', _blocks.length.toString()),
                  _summaryItem('طبقات', _totalFloors.toString()),
                  _summaryItem('واحدها', _totalUnits.toString()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: isSaving ? null : _submit,
            child: isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('ساخت پروژه'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _summaryItem(String label, String value) => Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label),
        ],
      );

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('نام پروژه را وارد کنید.')));
      return;
    }

    final blockInputs = _blocks.map((b) => b.toInput()).toList();
    final id = await ref.read(projectBuilderControllerProvider.notifier).create(
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          description: _descriptionController.text.trim(),
          blocks: blockInputs,
        );

    if (id != null && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پروژه با موفقیت ساخته شد.')),
      );
    }
  }
}

/// State قابل‌ویرایش یک بلوک در فرم (شامل چند گروه طبقه)
class _BlockForm {
  final nameController = TextEditingController(text: 'بلوک ${DateTime.now().microsecond % 100}');
  final List<_FloorGroupForm> groups = [_FloorGroupForm()];

  BlockInput toInput() => BlockInput(
        name: nameController.text.trim().isEmpty
            ? 'بلوک بدون‌نام'
            : nameController.text.trim(),
        floorGroups: groups.map((g) => g.toInput()).toList(),
      );
}

class _FloorGroupForm {
  FloorType type = FloorType.residential;
  final startController = TextEditingController(text: '1');
  final endController = TextEditingController(text: '1');
  final repeatController = TextEditingController(text: '1');
  final unitsController = TextEditingController(text: '0');

  FloorGroupInput toInput() {
    if (type == FloorType.residential) {
      return FloorGroupInput(
        type: type,
        floorStart: int.tryParse(startController.text) ?? 1,
        floorEnd: int.tryParse(endController.text) ?? 1,
        unitsPerFloor: int.tryParse(unitsController.text) ?? 0,
      );
    }
    return FloorGroupInput(
      type: type,
      repeatCount: int.tryParse(repeatController.text) ?? 1,
      unitsPerFloor: int.tryParse(unitsController.text) ?? 0,
    );
  }
}

class _BlockEditor extends StatelessWidget {
  final _BlockForm block;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _BlockEditor({
    super.key,
    required this.block,
    required this.index,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: block.nameController,
                    textAlign: TextAlign.right,
                    decoration:
                        InputDecoration(labelText: 'نام بلوک ${index + 1}'),
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...block.groups.asMap().entries.map(
                  (e) => _FloorGroupEditor(
                    group: e.value,
                    onRemove: block.groups.length > 1
                        ? () {
                            block.groups.removeAt(e.key);
                            onChanged();
                          }
                        : null,
                    onChanged: onChanged,
                  ),
                ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  block.groups.add(_FloorGroupForm());
                  onChanged();
                },
                icon: const Icon(Icons.add),
                label: const Text('افزودن گروه طبقه'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloorGroupEditor extends StatelessWidget {
  final _FloorGroupForm group;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _FloorGroupEditor({
    required this.group,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isResidential = group.type == FloorType.residential;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<FloorType>(
                  value: group.type,
                  decoration: const InputDecoration(labelText: 'نوع طبقه'),
                  items: const [
                    DropdownMenuItem(
                        value: FloorType.parking, child: Text('پارکینگ')),
                    DropdownMenuItem(
                        value: FloorType.ground, child: Text('همکف')),
                    DropdownMenuItem(
                        value: FloorType.residential,
                        child: Text('مسکونی (بازه طبقه)')),
                    DropdownMenuItem(
                        value: FloorType.roof, child: Text('بام')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      group.type = v;
                      onChanged();
                    }
                  },
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (isResidential)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: group.startController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: 'از طبقه'),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: group.endController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: 'تا طبقه'),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            )
          else
            TextField(
              controller: group.repeatController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'تعداد طبقه از این نوع'),
              onChanged: (_) => onChanged(),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: group.unitsController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration:
                const InputDecoration(labelText: 'تعداد واحد در هر طبقه (۰ = بدون واحد)'),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}
