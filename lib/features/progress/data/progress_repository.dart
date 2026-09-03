import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../domain/progress_record.dart';

class ProgressRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  ProgressRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _records =>
      _firestore.collection('progressRecords');

  /// ثبت پیشرفت جدید — طبق بند ۱۰: تاریخ و ثبت‌کننده کاملاً خودکارند و
  /// کاربر نمی‌تواند آن‌ها را وارد یا تغییر دهد. عکس اختیاری است (بند ۱۱).
  /// این رکورد هرگز Overwrite نمی‌شود (بند ۱۳) — همیشه سند جدید ساخته می‌شود
  /// و Firestore Rules هم Update/Delete را برای این کالکشن رد می‌کند.
  Future<void> submitProgress({
    required String projectId,
    required String blockId,
    required String floorId,
    String? unitId,
    required String checklistCategoryId,
    required String checklistItemId,
    required double progressPercent,
    String description = '',
    File? photo,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('کاربر وارد نشده است.');
    }

    // username نمایشی برای گزارش‌ها؛ خودِ createdBy همیشه uid است (منحصربه‌فرد
    // و غیرقابل‌جعل)، username را از سند users می‌خوانیم.
    final userDoc =
        await _firestore.collection('users').doc(user.uid).get();
    final username = userDoc.data()?['username'] as String? ?? user.uid;

    String? photoUrl;
    if (photo != null) {
      final ref = _storage.ref().child(
          'progress_photos/$projectId/${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg');
      await ref.putFile(photo);
      photoUrl = await ref.getDownloadURL();
    }

    await _records.add({
      'projectId': projectId,
      'blockId': blockId,
      'floorId': floorId,
      'unitId': unitId,
      'checklistCategoryId': checklistCategoryId,
      'checklistItemId': checklistItemId,
      'progressPercent': progressPercent,
      'description': description,
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(), // ← سرور مقدار می‌دهد
      'createdBy': user.uid, // ← از session سرور، نه ورودی کاربر
      'createdByUsername': username,
    });
  }

  /// تاریخچه کامل یک فعالیت در یک مکان مشخص (بند ۱۳) — جدیدترین اول.
  Stream<List<ProgressRecord>> streamHistory({
    required String checklistItemId,
    required String blockId,
    required String floorId,
    String? unitId,
  }) {
    Query<Map<String, dynamic>> query = _records
        .where('checklistItemId', isEqualTo: checklistItemId)
        .where('blockId', isEqualTo: blockId)
        .where('floorId', isEqualTo: floorId);
    query = unitId == null
        ? query.where('unitId', isNull: true)
        : query.where('unitId', isEqualTo: unitId);

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ProgressRecord.fromDoc).toList());
  }

  /// قانون اصلی گزارش تاریخی (بند ۱۴):
  /// آخرین رکورد با createdAt <= تاریخ گزارش انتخاب‌شده = وضعیت آن فعالیت
  /// در آن تاریخ. یک Query ساده روی همان کالکشن، بدون نیاز به Cloud Function.
  Future<ProgressRecord?> latestAsOf({
    required String checklistItemId,
    required String blockId,
    required String floorId,
    String? unitId,
    required DateTime asOf,
  }) async {
    Query<Map<String, dynamic>> query = _records
        .where('checklistItemId', isEqualTo: checklistItemId)
        .where('blockId', isEqualTo: blockId)
        .where('floorId', isEqualTo: floorId);
    query = unitId == null
        ? query.where('unitId', isNull: true)
        : query.where('unitId', isEqualTo: unitId);

    final snap = await query
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(asOf))
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return ProgressRecord.fromDoc(snap.docs.first);
  }

  /// همه رکوردهای یک پروژه تا یک تاریخ مشخص — پایه محاسبهٔ داشبورد در
  /// ماژول گزارش (Phase 9). چون فایراستور امکان «آخرین رکورد هر گروه» را
  /// در یک Query واحد نمی‌دهد، همه رکوردهای تا آن تاریخ خوانده و سمت کلاینت
  /// بر اساس (checklistItemId+blockId+floorId+unitId) گروه‌بندی می‌شوند و
  /// جدیدترین هرکدام نگه داشته می‌شود.
  Future<List<ProgressRecord>> allRecordsUpTo({
    required String projectId,
    required DateTime asOf,
  }) async {
    final snap = await _records
        .where('projectId', isEqualTo: projectId)
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(asOf))
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map(ProgressRecord.fromDoc).toList();
  }

  /// همه رکوردهای پروژه بدون فیلتر تاریخ — برای نمودار روند پیشرفت (بند ۱۶)
  Future<List<ProgressRecord>> allRecords(String projectId) async {
    final snap = await _records
        .where('projectId', isEqualTo: projectId)
        .orderBy('createdAt')
        .get();
    return snap.docs.map(ProgressRecord.fromDoc).toList();
  }
}
