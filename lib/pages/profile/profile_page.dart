import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../core/auth/token_storage.dart';
import '../../core/auth/roles.dart';
import '../../core/config/fcm_service.dart';
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
  AuthorizationStatus? _notificationStatus;
  PermissionStatus? _cameraStatus;
  PermissionStatus? _photosStatus;
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
    final notificationSettings = await FirebaseMessaging.instance
        .getNotificationSettings();
    final cameraStatus = await Permission.camera.status;
    final photosStatus = Platform.isIOS
        ? await Permission.photos.status
        : PermissionStatus.granted;

    if (!mounted) return;
    setState(() {
      _notificationStatus = notificationSettings.authorizationStatus;
      _cameraStatus = cameraStatus;
      _photosStatus = photosStatus;
      _checkingPermissions = false;
    });
  }

  Future<void> _requestNotifications() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (!mounted) return;
    setState(() => _notificationStatus = settings.authorizationStatus);
  }

  Future<void> _requestCamera() async {
    final current = await Permission.camera.status;
    if (current.isPermanentlyDenied || current.isRestricted) {
      await openAppSettings();
      return;
    }
    await Permission.camera.request();
    await _refreshPermissions();
  }

  Future<void> _requestPhotos() async {
    if (!Platform.isIOS) return;
    final current = await Permission.photos.status;
    if (current.isPermanentlyDenied || current.isRestricted) {
      await openAppSettings();
      return;
    }
    await Permission.photos.request();
    await _refreshPermissions();
  }

  bool get _notificationsAllowed =>
      _notificationStatus == AuthorizationStatus.authorized ||
      _notificationStatus == AuthorizationStatus.provisional;

  String _permissionLabel(bool granted) =>
      granted ? 'Permitido' : 'Requiere permiso';

  Widget _buildPermissionRow({
    required IconData icon,
    required String title,
    required String description,
    required bool granted,
    required VoidCallback? onPressed,
  }) {
    final color = granted ? const Color(0xFF15803D) : const Color(0xFFB45309);
    return Semantics(
      label: '$title. ${_permissionLabel(granted)}. $description',
      button: onPressed != null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 4),
            Text(
              _permissionLabel(granted),
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        trailing: granted || onPressed == null
            ? Icon(Icons.check_circle, color: color)
            : TextButton(onPressed: onPressed, child: const Text('Permitir')),
        onTap: granted ? null : onPressed,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
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

              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  header: true,
                  child: const Text(
                    'Permisos de la aplicación',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Estos permisos permiten recibir alertas y adjuntar evidencia. La app no solicita tu ubicación actual.',
                  style: TextStyle(color: Color(0xFF616161), height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _checkingPermissions
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Column(
                        children: [
                          _buildPermissionRow(
                            icon: Icons.notifications_active_outlined,
                            title: 'Notificaciones',
                            description:
                                'Necesarias para recibir mensajes, reportes y emergencias del barrio.',
                            granted: _notificationsAllowed,
                            onPressed: _notificationsAllowed
                                ? null
                                : _requestNotifications,
                          ),
                          const Divider(height: 1),
                          _buildPermissionRow(
                            icon: Icons.camera_alt_outlined,
                            title: 'Cámara',
                            description:
                                'Opcional. Se usa para fotografiar evidencia.',
                            granted: _cameraStatus?.isGranted ?? false,
                            onPressed: _cameraStatus?.isGranted == true
                                ? null
                                : _requestCamera,
                          ),
                          const Divider(height: 1),
                          _buildPermissionRow(
                            icon: Icons.photo_library_outlined,
                            title: 'Galería',
                            description: Platform.isIOS
                                ? 'Opcional. Permite elegir evidencia guardada.'
                                : 'Android utiliza el selector privado del sistema sin dar acceso completo.',
                            granted:
                                Platform.isAndroid ||
                                _photosStatus?.isGranted == true ||
                                _photosStatus?.isLimited == true,
                            onPressed:
                                Platform.isIOS &&
                                    _photosStatus?.isGranted != true &&
                                    _photosStatus?.isLimited != true
                                ? _requestPhotos
                                : null,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
              const SizedBox(height: 40),

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
