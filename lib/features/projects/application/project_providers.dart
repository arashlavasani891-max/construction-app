import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/project_repository.dart';
import '../domain/project.dart';
import '../domain/structure_builder_input.dart';
import '../../auth/application/auth_controller.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository();
});

/// پروژه‌های قابل‌مشاهده برای کاربر جاری — ادمین همه را می‌بیند،
/// کاربر عادی فقط پروژه‌های assign‌شده (بند ۳).
final visibleProjectsProvider = StreamProvider<List<Project>>((ref) async* {
  final appUser = await ref.watch(currentAppUserProvider.future);
  final repo = ref.watch(projectRepositoryProvider);

  if (appUser == null) {
    yield const [];
    return;
  }
  if (appUser.isAdmin) {
    yield* repo.streamAllProjects();
  } else {
    yield* repo.streamProjectsForUser(appUser.assignedProjectIds);
  }
});

final blocksOfProjectProvider =
    StreamProvider.family<List<Block>, String>((ref, projectId) {
  return ref.watch(projectRepositoryProvider).streamBlocks(projectId);
});

final blockNamesProvider =
    FutureProvider.family<Map<String, String>, String>((ref, projectId) {
  return ref.watch(projectRepositoryProvider).blockNames(projectId);
});

final floorNamesProvider =
    FutureProvider.family<Map<String, String>, String>((ref, projectId) {
  return ref.watch(projectRepositoryProvider).floorNames(projectId);
});

final floorsOfBlockProvider =
    StreamProvider.family<List<Floor>, String>((ref, blockId) {
  return ref.watch(projectRepositoryProvider).streamFloors(blockId);
});

final unitsOfFloorProvider =
    StreamProvider.family<List<Unit>, String>((ref, floorId) {
  return ref.watch(projectRepositoryProvider).streamUnits(floorId);
});

/// وضعیت فرم «ساخت پروژه جدید» در پنل مدیریت (بند ۴)
class ProjectBuilderController extends StateNotifier<AsyncValue<void>> {
  ProjectBuilderController(this._repository) : super(const AsyncData(null));

  final ProjectRepository _repository;

  Future<String?> create({
    required String name,
    required String code,
    required String description,
    required List<BlockInput> blocks,
  }) async {
    state = const AsyncLoading();
    String? newId;
    state = await AsyncValue.guard(() async {
      newId = await _repository.createProjectWithStructure(
        name: name,
        code: code,
        description: description,
        blocks: blocks,
      );
    });
    return newId;
  }
}

final projectBuilderControllerProvider =
    StateNotifierProvider<ProjectBuilderController, AsyncValue<void>>((ref) {
  return ProjectBuilderController(ref.watch(projectRepositoryProvider));
});
