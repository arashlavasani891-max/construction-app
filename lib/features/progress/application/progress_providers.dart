import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/progress_repository.dart';
import '../domain/progress_record.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository();
});

final progressHistoryProvider = StreamProvider.family<List<ProgressRecord>,
    ({String checklistItemId, String blockId, String floorId, String? unitId})>(
  (ref, params) {
    return ref.watch(progressRepositoryProvider).streamHistory(
          checklistItemId: params.checklistItemId,
          blockId: params.blockId,
          floorId: params.floorId,
          unitId: params.unitId,
        );
  },
);

class ProgressEntryController extends StateNotifier<AsyncValue<void>> {
  ProgressEntryController(this._repository) : super(const AsyncData(null));
  final ProgressRepository _repository;

  Future<bool> submit({
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
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.submitProgress(
          projectId: projectId,
          blockId: blockId,
          floorId: floorId,
          unitId: unitId,
          checklistCategoryId: checklistCategoryId,
          checklistItemId: checklistItemId,
          progressPercent: progressPercent,
          description: description,
          photo: photo,
        ));
    return !state.hasError;
  }
}

final progressEntryControllerProvider =
    StateNotifierProvider<ProgressEntryController, AsyncValue<void>>((ref) {
  return ProgressEntryController(ref.watch(progressRepositoryProvider));
});
