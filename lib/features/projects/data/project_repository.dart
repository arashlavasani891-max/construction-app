import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/project.dart';
import '../domain/structure_builder_input.dart';

/// حداکثر عملیات در هر WriteBatch فایراستور ۵۰۰ است؛
/// برای پروژه‌های بزرگ (چند بلوک × طبقات × واحد) از چند Batch پشت‌سرهم
/// استفاده می‌شود تا این سقف رعایت شود.
const _maxBatchOps = 400;

class ProjectRepository {
  final FirebaseFirestore _firestore;

  ProjectRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _projects =>
      _firestore.collection('projects');
  CollectionReference<Map<String, dynamic>> get _blocks =>
      _firestore.collection('blocks');
  CollectionReference<Map<String, dynamic>> get _floors =>
      _firestore.collection('floors');
  CollectionReference<Map<String, dynamic>> get _units =>
      _firestore.collection('units');

  /// جریان زنده همه پروژه‌ها (برای مدیر) — طبق بند ۲۳ (لحظه‌ای بودن)
  Stream<List<Project>> streamAllProjects() {
    return _projects
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Project.fromDoc).toList());
  }

  /// جریان پروژه‌های قابل‌مشاهده برای یک کاربر عادی (بند ۳: فقط پروژه‌های
  /// تخصیص‌داده‌شده). Firestore whereIn حداکثر ۳۰ مقدار می‌پذیرد که برای
  /// اکثر کاربران (چند پروژه) کافی است.
  Stream<List<Project>> streamProjectsForUser(List<String> assignedIds) {
    if (assignedIds.isEmpty) {
      return Stream.value(const []);
    }
    return _projects
        .where(FieldPath.documentId, whereIn: assignedIds.take(30).toList())
        .where('active', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map(Project.fromDoc).toList());
  }

  /// ساخت پروژه به همراه کل ساختار بلوک/طبقه/واحد در یک عملیات
  /// (طبق بند ۴: مدیر یک‌بار ساختار را تعریف می‌کند و سیستم خودش
  /// درخت پروژه→بلوک→طبقه→واحد را می‌سازد).
  Future<String> createProjectWithStructure({
    required String name,
    required String code,
    required String description,
    required List<BlockInput> blocks,
  }) async {
    final projectRef = _projects.doc();
    final pendingWrites = <_PendingWrite>[
      _PendingWrite(projectRef, {
        'name': name,
        'code': code,
        'description': description,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    ];

    var blockOrder = 0;
    for (final blockInput in blocks) {
      final blockRef = _blocks.doc();
      pendingWrites.add(_PendingWrite(blockRef, {
        'projectId': projectRef.id,
        'name': blockInput.name,
        'order': blockOrder++,
      }));

      var floorOrder = 0;
      for (final group in blockInput.floorGroups) {
        for (var i = 0; i < group.floorCount; i++) {
          final floorRef = _floors.doc();
          pendingWrites.add(_PendingWrite(floorRef, {
            'blockId': blockRef.id,
            'projectId': projectRef.id,
            'name': group.labelFor(i),
            'order': floorOrder++,
            'type': group.type.name,
            'unitsCount': group.unitsPerFloor,
          }));

          for (var u = 1; u <= group.unitsPerFloor; u++) {
            final unitRef = _units.doc();
            pendingWrites.add(_PendingWrite(unitRef, {
              'floorId': floorRef.id,
              'blockId': blockRef.id,
              'projectId': projectRef.id,
              'name': 'واحد $u',
            }));
          }
        }
      }
    }

    await _commitInChunks(pendingWrites);
    return projectRef.id;
  }

  Future<void> setProjectActive(String projectId, bool active) {
    return _projects.doc(projectId).update({'active': active});
  }

  Future<void> updateProjectInfo({
    required String projectId,
    required String name,
    required String description,
  }) {
    return _projects.doc(projectId).update({
      'name': name,
      'description': description,
    });
  }

  /// آرشیو پروژه به‌جای حذف فیزیکی. تاریخچه پیشرفت و گزارش‌ها نباید
  /// با حذف پروژه از بین بروند.
  Future<void> deleteProject(String projectId) {
    return _projects.doc(projectId).update({
      'active': false,
      'archivedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Block>> streamBlocks(String projectId) {
    return _blocks
        .where('projectId', isEqualTo: projectId)
        .orderBy('order')
        .snapshots()
        .map((s) => s.docs.map(Block.fromDoc).toList());
  }

  Stream<List<Floor>> streamFloors(String blockId) {
    return _floors
        .where('blockId', isEqualTo: blockId)
        .orderBy('order')
        .snapshots()
        .map((s) => s.docs.map(Floor.fromDoc).toList());
  }

  Stream<List<Unit>> streamUnits(String floorId) {
    return _units
        .where('floorId', isEqualTo: floorId)
        .snapshots()
        .map((s) => s.docs.map(Unit.fromDoc).toList());
  }

  /// نگاشت id→نام بلوک‌ها/طبقات یک پروژه — برای برچسب‌گذاری در Heatmap و
  /// نمودارهای گزارش (بند ۲۴-۲۶)؛ یک‌بار خوانده می‌شود، نیازی به Stream نیست.
  Future<Map<String, String>> blockNames(String projectId) async {
    final snap = await _blocks.where('projectId', isEqualTo: projectId).get();
    return {for (final d in snap.docs) d.id: (d.data()['name'] as String? ?? '')};
  }

  Future<Map<String, String>> floorNames(String projectId) async {
    final snap = await _floors.where('projectId', isEqualTo: projectId).get();
    return {for (final d in snap.docs) d.id: (d.data()['name'] as String? ?? '')};
  }

  Future<void> _commitInChunks(List<_PendingWrite> writes) async {
    for (var i = 0; i < writes.length; i += _maxBatchOps) {
      final chunk = writes.skip(i).take(_maxBatchOps);
      final batch = _firestore.batch();
      for (final w in chunk) {
        batch.set(w.ref, w.data);
      }
      await batch.commit();
    }
  }
}

class _PendingWrite {
  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, dynamic> data;
  _PendingWrite(this.ref, this.data);
}
