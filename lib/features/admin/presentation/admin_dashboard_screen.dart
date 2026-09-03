import 'package:flutter/material.dart';

import '../../checklist/presentation/checklist_admin_screen.dart';
import 'user_management_screen.dart';
import 'contractor_management_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _AdminMenuItem('چک‌لیست ساختمان', Icons.checklist, (ctx) =>
          Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ChecklistAdminScreen()))),
      _AdminMenuItem('کاربران', Icons.people_outline, (ctx) =>
          Navigator.push(ctx, MaterialPageRoute(builder: (_) => const UserManagementScreen()))),
      _AdminMenuItem('پیمانکاران', Icons.groups_outlined, (ctx) => Navigator.push(
          ctx, MaterialPageRoute(builder: (_) => const ContractorManagementScreen()))),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('پنل مدیریت')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: items
            .map((item) => Card(
                  child: InkWell(
                    onTap: () => item.onTap(context),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.icon, size: 36),
                        const SizedBox(height: 8),
                        Text(item.label),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _AdminMenuItem {
  final String label;
  final IconData icon;
  final void Function(BuildContext) onTap;
  _AdminMenuItem(this.label, this.icon, this.onTap);
}
