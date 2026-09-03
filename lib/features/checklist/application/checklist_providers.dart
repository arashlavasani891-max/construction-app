import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/checklist_repository.dart';
import '../domain/checklist_models.dart';

final checklistRepositoryProvider = Provider<ChecklistRepository>((ref) {
  return ChecklistRepository();
});

final checklistCategoriesProvider =
    StreamProvider<List<ChecklistCategory>>((ref) {
  return ref.watch(checklistRepositoryProvider).streamCategories();
});

final checklistItemsProvider =
    StreamProvider.family<List<ChecklistItem>, String>((ref, categoryId) {
  return ref
      .watch(checklistRepositoryProvider)
      .streamItemsOfCategory(categoryId);
});
