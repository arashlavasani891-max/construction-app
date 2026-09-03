import 'package:cloud_firestore/cloud_firestore.dart';

class Contractor {
  final String id;
  final String name;
  final String code;
  final String activityType;
  final String description;
  final bool active;

  const Contractor({
    required this.id,
    required this.name,
    required this.code,
    required this.activityType,
    required this.description,
    required this.active,
  });

  factory Contractor.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Contractor(
      id: doc.id,
      name: d['name'] as String? ?? '',
      code: d['code'] as String? ?? '',
      activityType: d['activityType'] as String? ?? '',
      description: d['description'] as String? ?? '',
      active: d['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'code': code,
        'activityType': activityType,
        'description': description,
        'active': active,
      };
}

class WorkforceRecord {
  final String id;
  final String projectId;
  final String contractorId;
  final String contractorName;
  final String activityDescription;
  final int skilledCount;
  final int laborCount;
  final int totalCount;
  final String description;
  final Timestamp createdAt;
  final String createdBy;
  final String createdByUsername;

  const WorkforceRecord({
    required this.id,
    required this.projectId,
    required this.contractorId,
    required this.contractorName,
    required this.activityDescription,
    required this.skilledCount,
    required this.laborCount,
    required this.totalCount,
    required this.createdAt,
    required this.createdBy,
    required this.createdByUsername,
    this.description = '',
  });

  factory WorkforceRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return WorkforceRecord(
      id: doc.id,
      projectId: d['projectId'] as String? ?? '',
      contractorId: d['contractorId'] as String? ?? '',
      contractorName: d['contractorName'] as String? ?? '',
      activityDescription: d['activityDescription'] as String? ?? '',
      skilledCount: d['skilledCount'] as int? ?? 0,
      laborCount: d['laborCount'] as int? ?? 0,
      totalCount: d['totalCount'] as int? ?? 0,
      description: d['description'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
      createdBy: d['createdBy'] as String? ?? '',
      createdByUsername: d['createdByUsername'] as String? ?? '',
    );
  }
}
