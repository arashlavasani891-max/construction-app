import 'package:cloud_firestore/cloud_firestore.dart';

class ChecklistCategory {
  final String id;
  final String name; // ابنیه، مکانیک، برق، ...
  final int order;

  const ChecklistCategory({
    required this.id,
    required this.name,
    required this.order,
  });

  factory ChecklistCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ChecklistCategory(
      id: doc.id,
      name: d['name'] as String? ?? '',
      order: d['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'order': order};
}

/// آیتم چک‌لیست با ساختار درختی (بند ۷) و پشتیبانی از فازبندی (بند ۸)
/// از طریق parentItemId خودارجاع. weight فقط روی آیتم‌های اصلی معنا دارد
/// (بند ۲۸) و برای زیرمرحله‌ها می‌تواند صفر باشد.
class ChecklistItem {
  final String id;
  final String categoryId;
  final String? parentItemId;
  final String name;
  final int order;
  final double weight; // درصد وزن در پیشرفت کل (بند ۲۸)

  const ChecklistItem({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.order,
    this.parentItemId,
    this.weight = 0,
  });

  factory ChecklistItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ChecklistItem(
      id: doc.id,
      categoryId: d['categoryId'] as String? ?? '',
      parentItemId: d['parentItemId'] as String?,
      name: d['name'] as String? ?? '',
      order: d['order'] as int? ?? 0,
      weight: (d['weight'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'categoryId': categoryId,
        'parentItemId': parentItemId,
        'name': name,
        'order': order,
        'weight': weight,
      };

  bool get isTopLevel => parentItemId == null;
}
