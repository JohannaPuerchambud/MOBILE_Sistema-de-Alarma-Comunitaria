import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'report_model.dart';
import 'report_service.dart';
import '../../core/auth/token_storage.dart';

class ReportListPage extends StatefulWidget {
  const ReportListPage({super.key});

  @override
  State<ReportListPage> createState() => _ReportListPageState();
}

class _ReportListPageState extends State<ReportListPage> {
  final _service = ReportService();

  bool loading = true;
  String? error;
  List<ReportModel> reports = [];

  int? roleId; // ✅ ahora está dentro del state

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadRole();
    await _load();
  }

  Future<void> _loadRole() async {
    try {
      final token = await TokenStorage().getToken();
      if (token == null || token.isEmpty) {
        roleId = null;
        return;
      }

      final decoded = JwtDecoder.decode(token);
      final role = decoded['role'];

      if (role is int) roleId = role;
      if (role is String) roleId = int.tryParse(role);

      setState(() {});
    } catch (_) {
      // Si falla el decode, no crasheamos
      roleId = null;
      setState(() {});
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await _service.getNeighborhoodReports();
      if (!mounted) return;
      setState(() => reports = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _formatDate(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}/"
        "${dt.month.toString().padLeft(2, '0')}/"
        "${dt.year} ${dt.hour.toString().padLeft(2, '0')}:"
        "${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final canCreateReport = roleId == 3; // ✅ solo Usuario

    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'Reportes del barrio',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        iconTheme: const IconThemeData(color: Colors.white), // Flecha de retroceso en blanco
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
      backgroundColor: const Color(0xFFF4F6F9), // Fondo sutil para contrastar las tarjetas blancas
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF667EEA)))
          : error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 16), textAlign: TextAlign.center),
        ),
      )
          : reports.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text("Tu barrio está tranquilo.", style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w600)),
            Text("No hay reportes todavía.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : RefreshIndicator(
        color: const Color(0xFF667EEA),
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (_, i) {
            final r = reports[i];

            final author = [
              if ((r.name ?? '').isNotEmpty) r.name,
              if ((r.lastName ?? '').isNotEmpty) r.lastName,
            ].whereType<String>().join(' ');

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 3,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título con ícono de alerta
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              r.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF333333))
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Descripción
                    Text(r.description, style: const TextStyle(fontSize: 15, color: Color(0xFF555555), height: 1.4)),
                    const SizedBox(height: 12),

                    // Imagen (Si existe)
                    if (r.imageUrl != null && r.imageUrl!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          r.imageUrl!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 180,
                              color: Colors.grey[200],
                              child: const Center(child: CircularProgressIndicator(color: Color(0xFF667EEA))),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                  height: 180,
                                  color: Colors.grey[200],
                                  child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40))
                              ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    const Divider(height: 24, color: Color(0xFFEEEEEE), thickness: 1),

                    // Ubicación
                    if (r.address != null && r.address!.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, size: 18, color: Color(0xFF667EEA)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              r.address!,
                              style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF666666), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Pie de la tarjeta: Autor y Fecha
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            author.isNotEmpty ? author : "Usuario anónimo",
                            style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatDate(r.createdAt),
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),

                    // Aviso si el rol no permite crear reportes
                    if (!canCreateReport) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.redAccent, size: 16),
                            SizedBox(width: 6),
                            Text("Solo el rol Usuario puede crear reportes.", style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
