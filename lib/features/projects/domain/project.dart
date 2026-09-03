import 'package:cloud_firestore/cloud_firestore.dart';

enum FloorType { parking, ground, residential, roof }

FloorType floorTypeFromString(String value) {
  return FloorType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => FloorType.residential,
  );
}

class Project {
  final String id;
  final String name;
  final String code;
  final String description;
  final bool active;
  final Timestamp? createdAt;

  const Project({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.active,
    this.createdAt,
  });

  factory Project.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Project(
      id: doc.id,
      name: d['name'] as String? ?? '',
      code: d['code'] as String? ?? '',
      description: d['description'] as String? ?? '',
      active: d['active'] as bool? ?? true,
      createdAt: d['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'code': code,
        'description': description,
        'active': active,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      };
}

class Block {
  final String id;
  final String projectId;
  final String name;
  final int order;

  const Block({
    required this.id,
    required this.projectId,
    required this.name,
    required this.order,
  });

  factory Block.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Block(
      id: doc.id,
      projectId: d['projectId'] as String? ?? '',
      name: d['name'] as String? ?? '',
      order: d['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'name': name,
        'order': order,
      };
}

class Floor {
  final String id;
  final String blockId;
  final String projectId;
  final String name; // مثلاً «طبقه ۷»، «پارکینگ ۲»، «همکف»، «بام»
  final int order; // برای مرتب‌سازی نمایش (پایین به بالا یا برعکس)
  final FloorType type;
  final int unitsCount;

  const Floor({
    required this.id,
    required this.blockId,
    required this.projectId,
    required this.name,
    required this.order,
    required this.type,
    required this.unitsCount,
  });

  factory Floor.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Floor(
      id: doc.id,
      blockId: d['blockId'] as String? ?? '',
      projectId: d['projectId'] as String? ?? '',
      name: d['name'] as String? ?? '',
      order: d['order'] as int? ?? 0,
      type: floorTypeFromString(d['type'] as String? ?? 'residential'),
      unitsCount: d['unitsCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'blockId': blockId,
        'projectId': projectId,
        'name': name,
        'order': order,
        'type': type.name,
        'unitsCount': unitsCount,
      };
}

class Unit {
  final String id;
  final String floorId;
  final String blockId;
  final String projectId;
  final String name; // مثلاً «واحد ۱۲»

  const Unit({
    required this.id,
    required this.floorId,
    required this.blockId,
    required this.projectId,
    required this.name,
  });

  factory Unit.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Unit(
      id: doc.id,
      floorId: d['floorId'] as String? ?? '',
      blockId: d['blockId'] as String? ?? '',
      projectId: d['projectId'] as String? ?? '',
      name: d['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'floorId': floorId,
        'blockId': blockId,
        'projectId': projectId,
        'name': name,
      };
}
