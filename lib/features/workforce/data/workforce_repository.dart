import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/workforce_models.dart';

class WorkforceRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  WorkforceRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _contractors =>
      _firestore.collection('contractors');
  CollectionReference<Map<String, dynamic>> get _records =>
      _firestore.collection('workforceRecords');

  // ---------- پیمانکاران (بند ۲۲) ----------
  Stream<List<Contractor>> streamContractors() {
    return _contractors
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(Contractor.fromDoc).toList());
  }

  Future<void> addContractor(Contractor contractor) {
    return _contractors.add(contractor.toMap());
  }

  Future<void> updateContractor(Contractor contractor) {
    return _contractors.doc(contractor.id).update(contractor.toMap());
  }

  Future<void> setContractorActive(String id, bool active) {
    return _contractors.doc(id).update({'active': active});
  }

  Future<void> deleteContractor(String id) {
    return _contractors.doc(id).delete();
  }

  // ---------- استقرار روزانه (بند ۱۷-۱۸: Append-Only) ----------
  Future<void> submitWorkforce({
    required String projectId,
    required String contractorId,
    required String contractorName,
    required String activityDescription,
    required int skilledCount,
    required int laborCount,
    String description = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('کاربر وارد نشده است.');

    final userDoc =
        await _firestore.collection('users').doc(user.uid).get();
    final username = userDoc.data()?['username'] as String? ?? user.uid;

    await _records.add({
      'projectId': projectId,
      'contractorId': contractorId,
      'contractorName': contractorName,
      'activityDescription': activityDescription,
      'skilledCount': skilledCount,
      'laborCount': laborCount,
      'totalCount': skilledCount + laborCount, // بند ۱۷: مجموع خودکار
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
      'createdByUsername': username,
    });
  }

  /// همه ثبت‌های استقرار یک پروژه در یک بازه تاریخی — پایه گزارش (بند ۱۹)
  Future<List<WorkforceRecord>> recordsInRange({
    required String projectId,
    required DateTime from,
    required DateTime to,
  }) async {
    final snap = await _records
        .where('projectId', isEqualTo: projectId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('createdAt')
        .get();
    return snap.docs.map(WorkforceRecord.fromDoc).toList();
  }

  /// جریان زنده امروز — برای نمایش لحظه‌ای در داشبورد
  Stream<List<WorkforceRecord>> streamToday(String projectId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _records
        .where('projectId', isEqualTo: projectId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(WorkforceRecord.fromDoc).toList());
  }
}
