bool canAccessCommunityFeatures(int? role) => role == 2 || role == 3;

String communityRoleLabel(int? role) {
  if (role == 2) return 'Representante';
  if (role == 3) return 'Vecino';
  return 'Sin acceso comunitario';
}
