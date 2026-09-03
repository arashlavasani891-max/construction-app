import 'package:cloud_firestore/cloud_firestore.dart';

class ProgressRecord {
  final String id;
  final String projectId;
  final String blockId;
  final String floorId;
  final String? unitId;
  final String checklistCategoryId;
  final String checklistItemId;
  final double progressPercent;
  final String description;
  final String? photoUrl;
  final Timestamp createdAt;
  final String createdBy;
  final String createdByUsername;

  const ProgressRecord({
    required this.id,
    required this.projectId,
    required this.blockId,
    required this.floorId,
    required this.checklistCategoryId,
    required this.checklistItemId,
    required this.progressPercent,
    required this.createdAt,
    required this.createdBy,
    required this.createdByUsername,
    this.unitId,
    this.description = '',
    this.photoUrl,
  });

  factory ProgressRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ProgressRecord(
      id: doc.id,
      projectId: d['projectId'] as String? ?? '',
      blockId: d['blockId'] as String? ?? '',
      floorId: d['floorId'] as String? ?? '',
      unitId: d['unitId'] as String?,
      checklistCategoryId: d['checklistCategoryId'] as String? ?? '',
      checklistItemId: d['checklistItemId'] as String? ?? '',
      progressPercent: (d['progressPercent'] as num?)?.toDouble() ?? 0,
      description: d['description'] as String? ?? '',
      photoUrl: d['photoUrl'] as String?,
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
      createdBy: d['createdBy'] as String? ?? '',
      createdByUsername: d['createdByUsername'] as String? ?? '',
    );
  }
}
