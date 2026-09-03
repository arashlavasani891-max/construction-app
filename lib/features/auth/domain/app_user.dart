class AppUser {
  final String uid;
  final String username;
  final String displayName;
  final String roleId; // مثلاً 'admin', 'abnie_officer', ...
  final bool active;
  final List<String> assignedProjectIds;
  final List<String> assignedChecklistCategoryIds;

  const AppUser({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.roleId,
    required this.active,
    required this.assignedProjectIds,
    required this.assignedChecklistCategoryIds,
  });

  bool get isAdmin => roleId == 'admin';

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      username: map['username'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      roleId: map['roleId'] as String? ?? '',
      active: map['active'] as bool? ?? true,
      assignedProjectIds:
          List<String>.from(map['assignedProjectIds'] as List? ?? const []),
      assignedChecklistCategoryIds: List<String>.from(
          map['assignedChecklistCategoryIds'] as List? ?? const []),
    );
  }
}
