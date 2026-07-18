import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../core/auth/token_storage.dart';
import '../../core/auth/roles.dart';
import '../../core/config/fcm_service.dart';
import '../../core/permissions/app_permissions.dart';
import 'app_permissions_page.dart';
import '../login/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final storage = TokenStorage();

  String userName = "Cargando...";
  String userRole = "";
  String userEmail = "No disponible";
  String userPhone = "No disponible";
  String userAddress = "No disponible";
  String userNeighborhood = "Tu Barrio";
  AppPermissionsSnapshot? _permissions;
  bool _checkingPermissions = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _refreshPermissions();
  }

  Future<void> _loadUserData() async {
    final token = await storage.getToken();
    if (token != null) {
      final claims = JwtDecoder.decode(token);
      if (!mounted) return;
      setState(() {
        userName = "${claims['name'] ?? ''} ${claims['last_name'] ?? ''}"
            .trim();
        userRole = communityRoleLabel(int.tryParse('${claims['role']}'));
        userEmail = claims['email'] ?? "Sin correo";
        userPhone = claims['phone'] ?? "Sin teléfono";
        userAddress = claims['address'] ?? "Sin dirección registrada";
        userNeighborhood = claims['neighborhood_name'] ?? "Sin barrio asignado";
      });
    }
  }

  Future<void> _refreshPermissions() async {
    final snapshot = await AppPermissions.load();
    if (!mounted) return;
    setState(() {
      _permissions = snapshot;
      _checkingPermissions = false;
    });
  }

  Future<void> _openPermissions() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AppPermissionsPage()),
    );
    if (!mounted) return;
    await _refreshPermissions();
  }

  Future<void> logout(BuildContext context) async {
    await PushNotificationService.unregisterCurrentDevice();
    await storage.clearToken();
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF667EEA).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF667EEA), size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF333333),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Mi Perfil",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF4F6F9),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 55,
                      color: Color(0xFF667EEA),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                userName.isEmpty ? "Usuario" : userName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              Text(
                userRole,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 30),

              Card(
                elevation: 4,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        Icons.email_outlined,
                        "Correo Electrónico",
                        userEmail,
                      ),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      _buildInfoRow(
                        Icons.phone_outlined,
                        "Teléfono Celular",
                        userPhone,
                      ),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        "Dirección de Domicilio",
                        userAddress,
                      ),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      _buildInfoRow(
                        Icons.maps_home_work_outlined,
                        "Barrio Asignado",
                        userNeighborhood,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Semantics(
                button: true,
                label: _checkingPermissions
                    ? 'Permisos de la aplicación. Revisando estado.'
                    : 'Permisos de la aplicación. ${_permissions?.grantedCount ?? 0} de ${AppPermissionsSnapshot.totalCount} habilitados. Administrar permisos.',
                child: Card(
                  margin: EdgeInsets.zero,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _openPermissions,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF667EEA,
                              ).withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_outlined,
                              color: Color(0xFF667EEA),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Permisos de la aplicación',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _checkingPermissions
                                      ? 'Revisando permisos...'
                                      : '${_permissions?.grantedCount ?? 0} de ${AppPermissionsSnapshot.totalCount} habilitados',
                                  style: const TextStyle(
                                    color: Color(0xFF667EEA),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Notificaciones, cámara y galería',
                                  style: TextStyle(
                                    color: Color(0xFF616161),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF667EEA),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF333333),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    "Cerrar Sesión",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => logout(context),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
