import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/app_user.dart';
import '../../checklist/application/checklist_providers.dart';
import '../../projects/application/project_providers.dart';
import '../data/user_admin_repository.dart';

final userAdminRepositoryProvider = Provider<UserAdminRepository>((ref) {
  return UserAdminRepository();
});

final allUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(userAdminRepositoryProvider).streamUsers();
});

// نقش‌های پایه — مدیر می‌تواند از دیالوگ نقش دلخواه هم تایپ کند (بند ۲۱)
const _baseRoles = [
  'admin',
  'project_manager',
  'abnie_officer',
  'mechanic_officer',
  'electrical_officer',
  'deployment_officer',
];

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('مدیریت کاربران')),
      body: usersAsync.when(
        data: (users) => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: user.active ? null : Colors.grey,
                child: Text(user.username.isNotEmpty
                    ? user.username[0].toUpperCase()
                    : '?'),
              ),
              title: Text(user.displayName.isEmpty ? user.username : user.displayName),
              subtitle: Text('@${user.username} — ${user.roleId}'),
              trailing: Switch(
                value: user.active,
                onChanged: (v) => ref
                    .read(userAdminRepositoryProvider)
                    .setUserActive(user.uid, v),
              ),
              onTap: () => _editUserDialog(context, ref, user),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطا: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createUserDialog(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('کاربر جدید'),
      ),
    );
  }

  Future<void> _createUserDialog(BuildContext context, WidgetRef ref) async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final displayNameController = TextEditingController();
    String role = _baseRoles.first;
    final selectedProjects = <String>{};
    final selectedCategories = <String>{};

    final projects = await ref.read(visibleProjectsProvider.future);
    final categories = await ref.read(checklistCategoriesProvider.future);

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('کاربر جدید'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: usernameController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'نام کاربری'),
                ),
                TextField(
                  controller: passwordController,
                  textAlign: TextAlign.right,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'رمز عبور اولیه'),
                ),
                TextField(
                  controller: displayNameController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'نام نمایشی'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'نقش'),
                  items: _baseRoles
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => role = v ?? role),
                ),
                const SizedBox(height: 8),
                const Align(
                    alignment: Alignment.centerRight, child: Text('دسترسی به پروژه‌ها:')),
                ...projects.map((p) => CheckboxListTile(
                      dense: true,
                      title: Text(p.name),
                      value: selectedProjects.contains(p.id),
                      onChanged: (v) => setState(() {
                        v == true
                            ? selectedProjects.add(p.id)
                            : selectedProjects.remove(p.id);
                      }),
                    )),
                const SizedBox(height: 8),
                const Align(
                    alignment: Alignment.centerRight, child: Text('دسترسی به چک‌لیست:')),
                ...categories.map((c) => CheckboxListTile(
                      dense: true,
                      title: Text(c.name),
                      value: selectedCategories.contains(c.id),
                      onChanged: (v) => setState(() {
                        v == true
                            ? selectedCategories.add(c.id)
                            : selectedCategories.remove(c.id);
                      }),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('انصراف')),
            FilledButton(
              onPressed: () async {
                if (usernameController.text.trim().isEmpty ||
                    passwordController.text.length < 6) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(
                      content: Text('نام کاربری و رمز (حداقل ۶ کاراکتر) لازم است.')));
                  return;
                }
                try {
                  await ref.read(userAdminRepositoryProvider).createUser(
                        username: usernameController.text,
                        password: passwordController.text,
                        displayName: displayNameController.text.trim(),
                        roleId: role,
                        assignedProjectIds: selectedProjects.toList(),
                        assignedChecklistCategoryIds: selectedCategories.toList(),
                      );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext)
                        .showSnackBar(SnackBar(content: Text('خطا: $e')));
                  }
                }
              },
              child: const Text('ایجاد'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editUserDialog(
      BuildContext context, WidgetRef ref, AppUser user) async {
    String role = user.roleId;
    final selectedProjects = user.assignedProjectIds.toSet();
    final selectedCategories = user.assignedChecklistCategoryIds.toSet();

    final projects = await ref.read(visibleProjectsProvider.future);
    final categories = await ref.read(checklistCategoriesProvider.future);

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text('ویرایش دسترسی: ${user.username}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _baseRoles.contains(role) ? role : _baseRoles.first,
                  decoration: const InputDecoration(labelText: 'نقش'),
                  items: _baseRoles
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => role = v ?? role),
                ),
                const SizedBox(height: 8),
                const Align(
                    alignment: Alignment.centerRight, child: Text('دسترسی به پروژه‌ها:')),
                ...projects.map((p) => CheckboxListTile(
                      dense: true,
                      title: Text(p.name),
                      value: selectedProjects.contains(p.id),
                      onChanged: (v) => setState(() {
                        v == true
                            ? selectedProjects.add(p.id)
                            : selectedProjects.remove(p.id);
                      }),
                    )),
                const SizedBox(height: 8),
                const Align(
                    alignment: Alignment.centerRight, child: Text('دسترسی به چک‌لیست:')),
                ...categories.map((c) => CheckboxListTile(
                      dense: true,
                      title: Text(c.name),
                      value: selectedCategories.contains(c.id),
                      onChanged: (v) => setState(() {
                        v == true
                            ? selectedCategories.add(c.id)
                            : selectedCategories.remove(c.id);
                      }),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: dialogContext,
                  builder: (_) => AlertDialog(
                    content: Text('کاربر «${user.username}» حذف شود؟'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('انصراف')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('حذف')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref
                      .read(userAdminRepositoryProvider)
                      .deleteUserDoc(user.uid, user.username);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                }
              },
              child: const Text('حذف کاربر', style: TextStyle(color: Colors.red)),
            ),
            FilledButton(
              onPressed: () async {
                await ref.read(userAdminRepositoryProvider).updateUserAccess(
                      uid: user.uid,
                      roleId: role,
                      assignedProjectIds: selectedProjects.toList(),
                      assignedChecklistCategoryIds: selectedCategories.toList(),
                    );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
  }
}
