import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../auth/domain/app_user.dart';
import '../../../firebase_options.dart';

/// چون Firebase Auth سمت کلاینت اجازه نمی‌دهد یک کاربر لاگین‌شده، حساب Auth
/// کاربر دیگری بسازد بدون اینکه Session خودش عوض شود، از یک نمونه موقت و
/// جداگانه FirebaseApp استفاده می‌کنیم: کاربر جدید در آن نمونه ساخته و بلافاصله
/// از آن خارج می‌شود، و Session اصلی مدیر در FirebaseAuth.instance دست‌نخورده
/// می‌ماند. این یک روش رایج و کاملاً رایگان (بدون نیاز به Admin SDK/Cloud
/// Functions) برای این سناریو است.
class UserAdminRepository {
  final FirebaseFirestore _firestore;

  UserAdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// بند ۲۰: ساخت کاربر جدید با Username/Password/نقش/دسترسی‌ها
  Future<void> createUser({
    required String username,
    required String password,
    required String displayName,
    required String roleId,
    required List<String> assignedProjectIds,
    required List<String> assignedChecklistCategoryIds,
  }) async {
    final normalizedUsername = username.trim().toLowerCase();
    final internalEmail = '$normalizedUsername@construction.local';

    // نمونه موقت — با نامی یکتا تا با نمونه اصلی یا اجراهای موازی تداخل نکند
    final tempApp = await Firebase.initializeApp(
      name: 'userCreation_${DateTime.now().microsecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final credential = await tempAuth.createUserWithEmailAndPassword(
        email: internalEmail,
        password: password,
      );
      final newUid = credential.user!.uid;
      await tempAuth.signOut();

      // سند users و نگاشت usernames با Session اصلی مدیر نوشته می‌شود
      // (طبق firestore.rules فقط ادمین اجازه نوشتن این کالکشن‌ها را دارد)
      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(newUid), {
        'username': normalizedUsername,
        'displayName': displayName,
        'roleId': roleId,
        'active': true,
        'assignedProjectIds': assignedProjectIds,
        'assignedChecklistCategoryIds': assignedChecklistCategoryIds,
      });
      batch.set(_firestore.collection('usernames').doc(normalizedUsername), {
        'email': internalEmail,
        'uid': newUid,
      });
      await batch.commit();
    } finally {
      await tempApp.delete();
    }
  }

  Stream<List<AppUser>> streamUsers() {
    return _firestore.collection('users').snapshots().map(
        (s) => s.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList());
  }

  Future<void> updateUserAccess({
    required String uid,
    required String roleId,
    required List<String> assignedProjectIds,
    required List<String> assignedChecklistCategoryIds,
  }) {
    return _firestore.collection('users').doc(uid).update({
      'roleId': roleId,
      'assignedProjectIds': assignedProjectIds,
      'assignedChecklistCategoryIds': assignedChecklistCategoryIds,
    });
  }

  Future<void> setUserActive(String uid, bool active) {
    return _firestore.collection('users').doc(uid).update({'active': active});
  }

  /// حذف کامل کاربر (بند ۲۰). توجه: حذف واقعی حساب Auth کاربر دیگر از
  /// کلاینت ممکن نیست (نیازمند Admin SDK/Cloud Function پولی است)؛ در این
  /// نسخه رایگان، غیرفعال‌سازی (setUserActive=false) عملاً معادل حذف دسترسی
  /// است و سند Firestore کاربر حذف می‌شود تا از پنل‌ها ناپدید شود.
  Future<void> deleteUserDoc(String uid, String username) async {
    final batch = _firestore.batch();
    batch.delete(_firestore.collection('users').doc(uid));
    batch.delete(_firestore.collection('usernames').doc(username));
    await batch.commit();
  }
}
