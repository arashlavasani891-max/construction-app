import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/workforce_repository.dart';
import '../domain/workforce_models.dart';

final workforceRepositoryProvider = Provider<WorkforceRepository>((ref) {
  return WorkforceRepository();
});

final contractorsProvider = StreamProvider<List<Contractor>>((ref) {
  return ref.watch(workforceRepositoryProvider).streamContractors();
});

final todayWorkforceProvider =
    StreamProvider.family<List<WorkforceRecord>, String>((ref, projectId) {
  return ref.watch(workforceRepositoryProvider).streamToday(projectId);
});

class WorkforceEntryController extends StateNotifier<AsyncValue<void>> {
  WorkforceEntryController(this._repository) : super(const AsyncData(null));
  final WorkforceRepository _repository;

  Future<bool> submit({
    required String projectId,
    required String contractorId,
    required String contractorName,
    required String activityDescription,
    required int skilledCount,
    required int laborCount,
    String description = '',
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.submitWorkforce(
          projectId: projectId,
          contractorId: contractorId,
          contractorName: contractorName,
          activityDescription: activityDescription,
          skilledCount: skilledCount,
          laborCount: laborCount,
          description: description,
        ));
    return !state.hasError;
  }
}

final workforceEntryControllerProvider =
    StateNotifierProvider<WorkforceEntryController, AsyncValue<void>>((ref) {
  return WorkforceEntryController(ref.watch(workforceRepositoryProvider));
});
