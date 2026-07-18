import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/permissions/app_permissions.dart';

class AppPermissionsPage extends StatefulWidget {
  const AppPermissionsPage({super.key});

  @override
  State<AppPermissionsPage> createState() => _AppPermissionsPageState();
}

class _AppPermissionsPageState extends State<AppPermissionsPage>
    with WidgetsBindingObserver {
  AppPermissionsSnapshot? _permissions;
  bool _loading = true;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final snapshot = await AppPermissions.load();
    if (!mounted) return;
    setState(() {
      _permissions = snapshot;
      _loading = false;
    });
  }

  Future<void> _request(Future<void> Function() action) async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      await action();
      await _refreshPermissions();
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  void _showPermissionDetails({
    required String title,
    required IconData icon,
    required String description,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF667EEA), size: 32),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(color: Color(0xFF616161), height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          header: true,
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF667EEA),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }

  Widget _permissionRow({
    required IconData icon,
    required String title,
    required String description,
    required bool granted,
    required Future<void> Function()? onRequest,
  }) {
    final statusColor = granted
        ? const Color(0xFF15803D)
        : const Color(0xFFB45309);
    final status = granted ? 'Permitido' : 'Requiere permiso';

    return Semantics(
      label: '$title. $status',
      button: true,
      child: ListTile(
        minVerticalPadding: 10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: statusColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          status,
          style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
        ),
        trailing: granted
            ? Icon(Icons.check_circle, color: statusColor)
            : TextButton(
                onPressed: _requesting || onRequest == null
                    ? null
                    : () => _request(onRequest),
                child: const Text('Permitir'),
              ),
        onTap: () => _showPermissionDetails(
          title: title,
          icon: icon,
          description: description,
        ),
      ),
    );
  }

  Widget _permissionGroup(List<Widget> rows) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index < rows.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissions = _permissions;
    final grantedCount = permissions?.grantedCount ?? 0;
    final progress = grantedCount / AppPermissionsSnapshot.totalCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Permisos',
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
      body: RefreshIndicator(
        onRefresh: _refreshPermissions,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              margin: EdgeInsets.zero,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$grantedCount de ${AppPermissionsSnapshot.totalCount} habilitados',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFE7EAF8),
                              color: progress == 1
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFF667EEA),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'La aplicación solo solicita lo necesario para recibir alertas y adjuntar evidencia. No usa tu ubicación actual.',
                            style: TextStyle(
                              color: Color(0xFF616161),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            if (!_loading && permissions != null) ...[
              _sectionTitle('Esenciales'),
              _permissionGroup([
                _permissionRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Notificaciones',
                  description:
                      'Permiten recibir mensajes, reportes y emergencias del barrio, incluso cuando la aplicación está en segundo plano.',
                  granted: permissions.notificationsAllowed,
                  onRequest: AppPermissions.requestNotifications,
                ),
              ]),
              _sectionTitle('Evidencias'),
              _permissionGroup([
                _permissionRow(
                  icon: Icons.camera_alt_outlined,
                  title: 'Cámara',
                  description:
                      'Se utiliza únicamente cuando decides tomar una fotografía para adjuntarla como evidencia.',
                  granted: permissions.cameraAllowed,
                  onRequest: AppPermissions.requestCamera,
                ),
                _permissionRow(
                  icon: Icons.photo_library_outlined,
                  title: 'Galería',
                  description: Platform.isIOS
                      ? 'Permite elegir una fotografía existente para adjuntarla como evidencia.'
                      : 'Android utiliza el selector privado del sistema, por lo que la aplicación no recibe acceso completo a tu galería.',
                  granted: permissions.galleryAllowed,
                  onRequest: Platform.isIOS
                      ? AppPermissions.requestPhotos
                      : null,
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
