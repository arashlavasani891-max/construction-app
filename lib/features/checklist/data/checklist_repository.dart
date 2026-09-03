import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/checklist_models.dart';

class ChecklistRepository {
  final FirebaseFirestore _firestore;
  ChecklistRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _categories =>
      _firestore.collection('checklistCategories');
  CollectionReference<Map<String, dynamic>> get _items =>
      _firestore.collection('checklistItems');

  Stream<List<ChecklistCategory>> streamCategories() {
    return _categories
        .orderBy('order')
        .snapshots()
        .map((s) => s.docs.map(ChecklistCategory.fromDoc).toList());
  }

  Stream<List<ChecklistItem>> streamItemsOfCategory(String categoryId) {
    return _items
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('order')
        .snapshots()
        .map((s) => s.docs.map(ChecklistItem.fromDoc).toList());
  }

  Future<void> addCategory(String name, int order) {
    return _categories.add({'name': name, 'order': order});
  }

  Future<void> renameCategory(String id, String name) {
    return _categories.doc(id).update({'name': name});
  }

  Future<void> deleteCategory(String id) async {
    // فعالیت‌های زیرمجموعه هم حذف می‌شوند؛ سوابق پیشرفت (progressRecords)
    // دست‌نخورده باقی می‌مانند چون طبق بند ۳۷ تاریخچه هرگز حذف نمی‌شود.
    final itemsSnap = await _items.where('categoryId', isEqualTo: id).get();
    final batch = _firestore.batch();
    for (final doc in itemsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_categories.doc(id));
    await batch.commit();
  }

  /// افزودن فعالیت جدید (بند ۷) — با parentItemId اختیاری برای فازبندی (بند ۸)
  Future<void> addItem({
    required String categoryId,
    required String name,
    String? parentItemId,
    required int order,
    double weight = 0,
  }) {
    return _items.add(ChecklistItem(
      id: '',
      categoryId: categoryId,
      parentItemId: parentItemId,
      name: name,
      order: order,
      weight: weight,
    ).toMap());
  }

  Future<void> updateItem(ChecklistItem item) {
    return _items.doc(item.id).update(item.toMap());
  }

  Future<void> deleteItem(String itemId) async {
    // زیرمرحله‌های این آیتم هم حذف می‌شوند (حذف آبشاری یک سطحی؛ برای
    // درخت‌های عمیق‌تر Cloud Function لازم است که طبق تصمیم «کاملاً رایگان»
    // در این نسخه استفاده نشده — مدیر باید زیرمراحل عمیق را دستی حذف کند).
    final childrenSnap =
        await _items.where('parentItemId', isEqualTo: itemId).get();
    final batch = _firestore.batch();
    for (final doc in childrenSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_items.doc(itemId));
    await batch.commit();
  }

  Future<void> reorderItem(String itemId, int newOrder) {
    return _items.doc(itemId).update({'order': newOrder});
  }

  Future<void> moveItemToCategory(String itemId, String newCategoryId) {
    return _items.doc(itemId).update({
      'categoryId': newCategoryId,
      'parentItemId': null, // انتقال بین دسته یعنی خروج از فازبندی قبلی
    });
  }
}
