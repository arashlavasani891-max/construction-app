import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../checklist/application/checklist_providers.dart';
import '../../checklist/domain/checklist_models.dart';
import '../../progress/presentation/progress_entry_screen.dart';
import '../../workforce/presentation/workforce_entry_screen.dart';
import '../../workforce/presentation/workforce_report_screen.dart';
import '../../reports/presentation/report_dashboard_screen.dart';
import '../../export/presentation/export_center_screen.dart';
import '../domain/project.dart';

class ProjectHomeScreen extends ConsumerWidget {
  final Project project;
  const ProjectHomeScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUserAsync = ref.watch(currentAppUserProvider);
    final isAdmin = appUserAsync.valueOrNull?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(project.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ModuleCard(
            icon: Icons.checklist_rtl,
            title: 'چک‌لیست‌های ساختمان',
            subtitle: 'ابنیه، مکانیک، برق',
            onTap: () => _openChecklist(context, ref),
          ),
          const SizedBox(height: 12),
          _ModuleCard(
            icon: Icons.groups,
            title: 'استقرار نفرات پیمانکاران',
            subtitle: 'ثبت روزانه و گزارش',
            onTap: () => showModalBottomSheet(
              context: context,
              builder: (_) => SafeArea(
                child: Wrap(children: [
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('ثبت استقرار امروز'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => WorkforceEntryScreen(
                          projectId: project.id,
                          projectName: project.name,
                        ),
                      ));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bar_chart),
                    title: const Text('گزارش استقرار'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => WorkforceReportScreen(projectId: project.id),
                      ));
                    },
                  ),
                ]),
              ),
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 24),
            Text('مدیریت پروژه', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _ModuleCard(
              icon: Icons.dashboard_outlined,
              title: 'داشبورد و گزارش‌ها',
              subtitle: 'پیشرفت کل، Heatmap، نمودارها',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ReportDashboardScreen(
                  projectId: project.id,
                  projectName: project.name,
                ),
              )),
            ),
            const SizedBox(height: 12),
            _ModuleCard(
              icon: Icons.ios_share,
              title: 'خروجی Excel / PDF',
              subtitle: 'دانلود و اشتراک‌گذاری گزارش',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ExportCenterScreen(
                  projectId: project.id,
                  projectName: project.name,
                ),
              )),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openChecklist(BuildContext context, WidgetRef ref) async {
    final appUser = await ref.read(currentAppUserProvider.future);
    final categories = await ref.read(checklistCategoriesProvider.future);

    final visibleCategories = (appUser?.isAdmin ?? false)
        ? categories
        : categories
            .where((c) => appUser?.assignedChecklistCategoryIds.contains(c.id) ?? false)
            .toList();

    if (!context.mounted) return;

    if (visibleCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هیچ چک‌لیستی برای شما تعریف نشده است.')),
      );
      return;
    }

    if (visibleCategories.length == 1) {
      _goToCategory(context, visibleCategories.first);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: visibleCategories
              .map((c) => ListTile(
                    title: Text(c.name),
                    onTap: () {
                      Navigator.pop(context);
                      _goToCategory(context, c);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _goToCategory(BuildContext context, ChecklistCategory category) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ProgressEntryScreen(
        projectId: project.id,
        category: category,
      ),
    ));
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}
