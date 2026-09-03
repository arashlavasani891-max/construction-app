import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/project_providers.dart';
import '../../auth/application/auth_controller.dart';
import 'project_structure_builder_screen.dart';
import 'project_home_screen.dart';
import '../../admin/presentation/admin_dashboard_screen.dart';

class ProjectSelectionScreen extends ConsumerWidget {
  const ProjectSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(visibleProjectsProvider);
    final appUserAsync = ref.watch(currentAppUserProvider);
    final isAdmin = appUserAsync.valueOrNull?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('انتخاب پروژه'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'پنل مدیریت',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'خروج',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: projectsAsync.when(
        data: (projects) {
          if (projects.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'هیچ پروژه‌ای برای شما تعریف نشده است.\nبا مدیر سیستم تماس بگیرید.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: projects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final project = projects[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    Icons.apartment,
                    color: project.active ? null : Colors.grey,
                  ),
                  title: Text(project.name),
                  subtitle: Text(
                    project.description.isEmpty
                        ? 'کد: ${project.code}'
                        : project.description,
                  ),
                  trailing: !project.active
                      ? const Chip(label: Text('غیرفعال'))
                      : const Icon(Icons.chevron_left),
                  onTap: !project.active
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProjectHomeScreen(project: project),
                            ),
                          );
                        },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطا: $e')),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProjectStructureBuilderScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('پروژه جدید'),
            )
          : null,
    );
  }
}
