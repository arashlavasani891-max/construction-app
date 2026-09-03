import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// جریان زنده وضعیت لاگین (برای AuthGate در main.dart)
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// اطلاعات کامل کاربر جاری از Firestore (نقش، دسترسی‌ها و ...)
final currentAppUserProvider = FutureProvider<AppUser?>((ref) async {
  // هر بار authState تغییر کند، این Provider هم باید invalidate شود.
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).fetchCurrentAppUser();
});

/// وضعیت فرم ورود (Loading/Error) — مجزا از authStateProvider که فقط
/// وضعیت واقعی Firebase را نشان می‌دهد.
class LoginController extends StateNotifier<AsyncValue<void>> {
  LoginController(this._repository) : super(const AsyncData(null));

  final AuthRepository _repository;

  Future<void> submit({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      state = AsyncError(
        AuthFailure('نام کاربری و رمز عبور را وارد کنید.'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.signInWithUsername(username: username, password: password),
    );
  }

  Future<void> resetPassword(String username) async {
    if (username.trim().isEmpty) {
      state = AsyncError(
        AuthFailure('برای بازیابی رمز، ابتدا نام کاربری را وارد کنید.'),
        StackTrace.current,
      );
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.sendPasswordReset(username),
    );
  }
}

final loginControllerProvider =
    StateNotifierProvider<LoginController, AsyncValue<void>>((ref) {
  return LoginController(ref.watch(authRepositoryProvider));
});
