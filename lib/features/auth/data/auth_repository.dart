import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/app_user.dart';

/// خطای اختصاصی برای پیام‌های قابل‌فهم به کاربر فارسی‌زبان
class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);
}

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// صفحه ورود Username می‌گیرد (طبق بند ۲ پرامپت)، اما Firebase Auth
  /// نیازمند Email است؛ ابتدا از کالکشن usernames، ایمیل متناظر خوانده می‌شود.
  Future<void> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final normalized = username.trim().toLowerCase();

    final mappingDoc =
        await _firestore.collection('usernames').doc(normalized).get();

    if (!mappingDoc.exists) {
      throw AuthFailure('نام کاربری یافت نشد.');
    }

    final email = mappingDoc.data()?['email'] as String?;
    if (email == null) {
      throw AuthFailure('حساب کاربری معتبر نیست. با مدیر سیستم تماس بگیرید.');
    }

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapFirebaseError(e.code));
    }

    // بررسی فعال بودن کاربر (بند ۲۰: مدیر می‌تواند کاربر را غیرفعال کند)
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final active = userDoc.data()?['active'] as bool? ?? true;
      if (!active) {
        await _auth.signOut();
        throw AuthFailure('حساب کاربری شما غیرفعال شده است.');
      }
    }
  }

  Future<void> sendPasswordReset(String username) async {
    final normalized = username.trim().toLowerCase();
    final mappingDoc =
        await _firestore.collection('usernames').doc(normalized).get();

    if (!mappingDoc.exists) {
      throw AuthFailure('نام کاربری یافت نشد.');
    }
    final email = mappingDoc.data()?['email'] as String?;
    if (email == null) {
      throw AuthFailure('حساب کاربری معتبر نیست.');
    }
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() => _auth.signOut();

  Future<AppUser?> fetchCurrentAppUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(uid, doc.data()!);
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'رمز عبور نادرست است.';
      case 'user-disabled':
        return 'حساب کاربری غیرفعال شده است.';
      case 'too-many-requests':
        return 'تعداد تلاش‌ها زیاد بود. کمی بعد دوباره تلاش کنید.';
      default:
        return 'ورود ناموفق بود. اطلاعات را بررسی کنید.';
    }
  }
}
