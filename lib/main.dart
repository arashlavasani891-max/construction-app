import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/projects/presentation/project_selection_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: ConstructionApp()));
}

class ConstructionApp extends ConsumerWidget {
  const ConstructionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'کنترل پروژه ساختمان',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        // پیش‌فرض‌های Material/Widgets/Cupertino هنگام افزودن
        // flutter_localizations در Phase بعد اضافه می‌شوند.
      ],
      theme: AppTheme.light,
      builder: (context, child) {
        // راست‌چین اجباری در کل اپ طبق بند ۳۳ پرامپت
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const AuthGate(),
    );
  }
}

/// بر اساس وضعیت لاگین کاربر، صفحه مناسب را نشان می‌دهد.
/// منطق کامل مسیریابی نقش/پروژه در Phase 2-3 تکمیل می‌شود.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) return const LoginScreen();
        return const ProjectSelectionScreen();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        body: Center(child: Text('خطا در اتصال: $err')),
      ),
    );
  }
}
