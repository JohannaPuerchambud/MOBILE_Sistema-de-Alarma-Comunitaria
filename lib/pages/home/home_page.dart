import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/fcm_service.dart';
import '../../features/reports/report_list_page.dart';
import '../../features/reports/report_create_page.dart';
import '../../features/chat/chat_page.dart';
import '../../features/emergency/emergency_service.dart';
import '../profile/profile_page.dart';
import '../../main.dart' show navigatorKey;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    PushNotificationService.init(navKey: navigatorKey);

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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                    width: 40, height: 4,
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
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_rounded, size: 48, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    "⚠️ ¿Estás seguro?",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Esto activará la sirena del barrio y alertará a todos los vecinos.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  // Campo de justificación
                  TextField(
                    controller: justificationCtrl,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText: "¿Por qué estás activando la alarma?",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
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
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              builder: (sheetCtx) => SafeArea(
                                child: Wrap(
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.camera_alt_outlined, color: Colors.redAccent),
                                      title: const Text('Tomar foto con la cámara'),
                                      onTap: () async {
                                        Navigator.pop(sheetCtx);
                                        final picked = await picker.pickImage(
                                          source: ImageSource.camera,
                                          imageQuality: 60,
                                          maxWidth: 800,
                                          maxHeight: 800,
                                        );
                                        if (picked != null) {
                                          setModalState(() => evidenceImage = File(picked.path));
                                        }
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.photo_library_outlined, color: Colors.redAccent),
                                      title: const Text('Elegir de la galería'),
                                      onTap: () async {
                                        Navigator.pop(sheetCtx);
                                        final picked = await picker.pickImage(
                                          source: ImageSource.gallery,
                                          imageQuality: 60,
                                          maxWidth: 800,
                                          maxHeight: 800,
                                        );
                                        if (picked != null) {
                                          setModalState(() => evidenceImage = File(picked.path));
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
                        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: evidenceImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.file(evidenceImage!, fit: BoxFit.cover),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined, size: 32, color: Color(0xFF999999)),
                                SizedBox(height: 6),
                                Text(
                                  "Toca para adjuntar evidencia",
                                  style: TextStyle(color: Color(0xFF777777), fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (evidenceImage != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: loading ? null : () => setModalState(() => evidenceImage = null),
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                        label: const Text("Quitar foto", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    ),
                  const SizedBox(height: 8),

                  // ✅ Error de validación dentro del modal (no SnackBar)
                  if (modalError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              modalError!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
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
                              final justification = justificationCtrl.text.trim();
                              if (justification.isEmpty) {
                                setModalState(() {
                                  modalError = "Escribe el motivo de la emergencia";
                                });
                                return;
                              }

                              setModalState(() {
                                loading = true;
                                modalError = null;
                              });

                              try {
                                await EmergencyService.triggerEmergency(
                                  justification: justification,
                                  imageFile: evidenceImage,
                                );

                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);

                                // Mostrar confirmación
                                _showEmergencySuccess();
                              } catch (e) {
                                setModalState(() {
                                  loading = false;
                                  modalError = e.toString().replaceFirst("Exception: ", "");
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: loading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Icon(Icons.campaign_rounded, size: 24),
                      label: Text(
                        loading ? "Activando..." : "ACTIVAR ALARMA",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Botón cancelar
                  TextButton(
                    onPressed: loading ? null : () => Navigator.pop(ctx),
                    child: const Text(
                      "Cancelar",
                      style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEmergencySuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 60, color: Colors.green),
            ),
            const SizedBox(height: 16),
            const Text(
              "¡Alarma Activada!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "La sirena se ha activado y tus vecinos han sido alertados con tu dirección registrada.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Aceptar", style: TextStyle(color: Color(0xFF667EEA), fontWeight: FontWeight.bold)),
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
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF667EEA).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF667EEA)),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
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
                child: GestureDetector(
                  onTap: _showEmergencyConfirmation,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                        center: Alignment.center,
                        radius: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.campaign_rounded, size: 50, color: Colors.white),
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

              const SizedBox(height: 28),

              // ═══════════════════════════════════════
              // ✅ SECCIÓN SECUNDARIA (Tarea 2.1)
              // ═══════════════════════════════════════
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Aplicaciones",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF555555)),
                ),
              ),
              const SizedBox(height: 14),

              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.05,
                  children: [
                    _buildDashboardCard(
                      title: "Mi Perfil",
                      icon: Icons.person_outline,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
                    ),
                    _buildDashboardCard(
                      title: "Reportar\nSospechoso",
                      icon: Icons.visibility_outlined,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportCreatePage())),
                    ),
                    _buildDashboardCard(
                      title: "Ver Reportes",
                      icon: Icons.list_alt_rounded,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportListPage())),
                    ),
                    _buildDashboardCard(
                      title: "Chat Barrial",
                      icon: Icons.forum_outlined,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatPage())),
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