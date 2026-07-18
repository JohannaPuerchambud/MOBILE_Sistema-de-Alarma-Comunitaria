import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/fcm_service.dart';
import '../../core/config/connectivity_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../features/reports/report_list_page.dart';
import '../../features/reports/report_create_page.dart';
import '../../features/chat/chat_page.dart';
import '../../features/emergency/emergency_service.dart';
import '../profile/profile_page.dart';
import '../../core/navigation/app_navigator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _online = true;

  @override
  void initState() {
    super.initState();
    PushNotificationService.init(navKey: appNavigatorKey);
    _connectivitySubscription = ConnectivityService.instance.connectionChanges
        .listen((connected) {
          if (mounted) setState(() => _online = connected);
        });
    ConnectivityService.instance.hasNetworkRoute().then((connected) {
      if (mounted) setState(() => _online = connected);
    });

    // Animación de pulso para el botón de emergencia
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ✅ Flujo de confirmación de emergencia (Tarea 2.2)
  void _showEmergencyConfirmation() {
    final justificationCtrl = TextEditingController();
    final picker = ImagePicker();
    bool loading = false;
    String? modalError;
    File? evidenceImage;
    String? emergencyType;
    const emergencyTypes = [
      'Robo',
      'Incendio',
      'Accidente',
      'Emergencia médica',
      'Otro',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Barra decorativa
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Ícono de alerta
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_rounded,
                        size: 48,
                        color: AppColors.emergency,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      "⚠️ ¿Estás seguro?",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Esto activará la sirena del barrio y alertará a todos los vecinos.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tipo de emergencia',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: emergencyTypes
                            .map(
                              (type) => ChoiceChip(
                                label: Text(type),
                                selected: emergencyType == type,
                                onSelected: loading
                                    ? null
                                    : (_) => setModalState(() {
                                        emergencyType = type;
                                        modalError = null;
                                      }),
                                selectedColor: AppColors.emergency.withValues(
                                  alpha: 0.16,
                                ),
                                side: BorderSide(
                                  color: emergencyType == type
                                      ? AppColors.emergency
                                      : const Color(0xFFD1D5DB),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Campo de justificación
                    TextField(
                      controller: justificationCtrl,
                      maxLines: 3,
                      maxLength: 200,
                      decoration: InputDecoration(
                        hintText: emergencyType == 'Otro'
                            ? 'Describe brevemente la emergencia'
                            : 'Detalle adicional (opcional)',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.redAccent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ✅ Evidencia fotográfica (opcional)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Evidencia fotográfica (Opcional)",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF555555),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: loading
                          ? null
                          : () {
                              showModalBottomSheet(
                                context: ctx,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                builder: (sheetCtx) => SafeArea(
                                  child: Wrap(
                                    children: [
                                      ListTile(
                                        leading: const Icon(
                                          Icons.camera_alt_outlined,
                                          color: Colors.redAccent,
                                        ),
                                        title: const Text(
                                          'Tomar foto con la cámara',
                                        ),
                                        onTap: () async {
                                          Navigator.pop(sheetCtx);
                                          final picked = await picker.pickImage(
                                            source: ImageSource.camera,
                                            imageQuality: 60,
                                            maxWidth: 800,
                                            maxHeight: 800,
                                          );
                                          if (picked != null) {
                                            setModalState(
                                              () => evidenceImage = File(
                                                picked.path,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.photo_library_outlined,
                                          color: Colors.redAccent,
                                        ),
                                        title: const Text(
                                          'Elegir de la galería',
                                        ),
                                        onTap: () async {
                                          Navigator.pop(sheetCtx);
                                          final picked = await picker.pickImage(
                                            source: ImageSource.gallery,
                                            imageQuality: 60,
                                            maxWidth: 800,
                                            maxHeight: 800,
                                          );
                                          if (picked != null) {
                                            setModalState(
                                              () => evidenceImage = File(
                                                picked.path,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          border: Border.all(
                            color: const Color(0xFFE0E0E0),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: evidenceImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.file(
                                  evidenceImage!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 32,
                                    color: Color(0xFF999999),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    "Toca para adjuntar evidencia",
                                    style: TextStyle(
                                      color: Color(0xFF777777),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (evidenceImage != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: loading
                              ? null
                              : () => setModalState(() => evidenceImage = null),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          label: const Text(
                            "Quitar foto",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),

                    // ✅ Error de validación dentro del modal (no SnackBar)
                    if (modalError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                modalError!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Botón de activar
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: loading
                            ? null
                            : () async {
                                final details = justificationCtrl.text.trim();
                                if (emergencyType == null) {
                                  setModalState(() {
                                    modalError =
                                        'Selecciona el tipo de emergencia';
                                  });
                                  return;
                                }
                                if (emergencyType == 'Otro' &&
                                    details.isEmpty) {
                                  setModalState(() {
                                    modalError =
                                        'Describe brevemente la emergencia';
                                  });
                                  return;
                                }
                                final justification = details.isEmpty
                                    ? emergencyType!
                                    : '${emergencyType!}: $details';

                                setModalState(() {
                                  loading = true;
                                  modalError = null;
                                });

                                try {
                                  final result =
                                      await EmergencyService.triggerEmergency(
                                        justification: justification,
                                        imageFile: evidenceImage,
                                      );

                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);

                                  // Mostrar confirmación
                                  _showEmergencySuccess(result);
                                } catch (e) {
                                  setModalState(() {
                                    loading = false;
                                    modalError =
                                        EmergencyService.userMessageForError(e);
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emergency,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Icon(Icons.campaign_rounded, size: 24),
                        label: Text(
                          loading ? "Activando..." : "ACTIVAR ALARMA",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Botón cancelar
                    TextButton(
                      onPressed: loading ? null : () => Navigator.pop(ctx),
                      child: const Text(
                        "Cancelar",
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _deliveryChannelRow({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Semantics(
      label: '$title. $message',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFF616161),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmergencySuccess(EmergencyResult result) {
    final pushDelivered =
        result.pushStatus == 'sent' || result.pushStatus == 'partially_sent';
    final sirenActivated = const {
      'queued',
      'ringing',
      'in-progress',
      'completed',
    }.contains(result.twilioStatus);
    final evidenceAttached = result.evidenceStatus == 'uploaded';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 60,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Emergencia Registrada",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Divider(height: 24),
            _deliveryChannelRow(
              icon: Icons.check_circle_outline,
              title: 'Registro',
              message: 'La emergencia quedó registrada en el barrio.',
              color: const Color(0xFF15803D),
            ),
            _deliveryChannelRow(
              icon: pushDelivered
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              title: 'Notificaciones a vecinos',
              message: result.pushMessage,
              color: pushDelivered
                  ? const Color(0xFF15803D)
                  : const Color(0xFFB45309),
            ),
            _deliveryChannelRow(
              icon: sirenActivated
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
              title: 'Sirena del barrio',
              message: result.sirenMessage,
              color: sirenActivated
                  ? const Color(0xFF15803D)
                  : const Color(0xFFB45309),
            ),
            _deliveryChannelRow(
              icon: evidenceAttached
                  ? Icons.image_outlined
                  : Icons.hide_image_outlined,
              title: 'Evidencia',
              message: result.evidenceMessage.isEmpty
                  ? 'No se adjuntó evidencia fotográfica.'
                  : result.evidenceMessage,
              color: evidenceAttached
                  ? const Color(0xFF15803D)
                  : const Color(0xFF64748B),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatPage()),
              );
            },
            icon: const Icon(Icons.forum_outlined),
            label: const Text('Ir al chat'),
          ),
          if (result.messageId != null)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportListPage(
                      initialActivityId: 'emergency-${result.messageId}',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Ver detalle'),
            ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1.5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF667EEA).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final compactHeight = screenSize.height < 700;
    final sosSize = compactHeight ? 124.0 : 150.0;
    final dashboardColumns = screenSize.width >= 720 ? 4 : 2;
    final dashboardRatio = screenSize.width >= 720 ? 1.25 : 1.05;

    return Scaffold(
      appBar: const AppGradientAppBar(title: 'Inicio'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              if (!_online)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: AppInlineMessage(
                    icon: Icons.wifi_off_rounded,
                    message:
                        'Sin conexión. El SOS y los envíos se habilitarán al recuperar internet.',
                    background: Color(0xFFFFF7ED),
                    foreground: AppColors.warning,
                  ),
                ),
              // ═══════════════════════════════════════
              // ✅ BOTÓN GIGANTE DE EMERGENCIA (Tarea 2.1)
              // ═══════════════════════════════════════
              const SizedBox(height: 10),
              const Text(
                "Emergencia",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF555555),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Presiona solo en caso de emergencia real",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // Botón con animación de pulso
              ScaleTransition(
                scale: _pulseAnimation,
                child: Semantics(
                  button: true,
                  enabled: _online,
                  label: 'Activar emergencia',
                  hint:
                      'Abre la confirmación antes de enviar la alerta al barrio',
                  child: GestureDetector(
                    onTap: _online
                        ? _showEmergencyConfirmation
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Necesitas internet para enviar una emergencia.',
                                ),
                              ),
                            );
                          },
                    child: Container(
                      width: sosSize,
                      height: sosSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                          center: Alignment.center,
                          radius: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.4),
                            blurRadius: 24,
                            spreadRadius: 4,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.campaign_rounded,
                            size: 50,
                            color: Colors.white,
                          ),
                          SizedBox(height: 4),
                          Text(
                            "SOS",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ═══════════════════════════════════════
              // ✅ SECCIÓN SECUNDARIA (Tarea 2.1)
              // ═══════════════════════════════════════
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Aplicaciones",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF555555),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Expanded(
                child: GridView.count(
                  crossAxisCount: dashboardColumns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: dashboardRatio,
                  children: [
                    _buildDashboardCard(
                      title: "Mi Perfil",
                      icon: Icons.person_outline,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfilePage()),
                      ),
                    ),
                    _buildDashboardCard(
                      title: "Reportar\nSospechoso",
                      icon: Icons.visibility_outlined,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReportCreatePage(),
                        ),
                      ),
                    ),
                    _buildDashboardCard(
                      title: "Actividad del Barrio",
                      icon: Icons.list_alt_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReportListPage(),
                        ),
                      ),
                    ),
                    _buildDashboardCard(
                      title: "Chat Barrial",
                      icon: Icons.forum_outlined,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChatPage()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
