import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'report_model.dart';
import 'report_service.dart';
import 'report_create_page.dart';

import '../../core/auth/token_storage.dart';
import '../../pages/login/login_page.dart';

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
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await _service.getNeighborhoodReports();
      setState(() => reports = data);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  String _formatDate(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}/"
        "${dt.month.toString().padLeft(2, '0')}/"
        "${dt.year} ${dt.hour.toString().padLeft(2, '0')}:"
        "${dt.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _logout() async {
    await TokenStorage().clearToken();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCreateReport = roleId == 3; // ✅ solo Usuario

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes del barrio'),
        actions: [
          IconButton(
            tooltip: 'Salir',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),

      // ✅ FAB solo si es Usuario
      floatingActionButton: canCreateReport
          ? FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const ReportCreatePage()),
          );
          if (created == true) _load();
        },
        child: const Icon(Icons.add),
      )
          : null,

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : reports.isEmpty
          ? const Center(child: Text("No hay reportes todavía."))
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          itemCount: reports.length,
          itemBuilder: (_, i) {
            final r = reports[i];

            final author = [
              if ((r.name ?? '').isNotEmpty) r.name,
              if ((r.lastName ?? '').isNotEmpty) r.lastName,
            ].whereType<String>().join(' ');

            return Card(
              margin: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              child: ListTile(
                title: Text(r.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(r.description),
                    const SizedBox(height: 8),
                    if (r.imageUrl != null && r.imageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          r.imageUrl!,
                          height: 150, // Altura fija para no descuadrar la lista
                          width: double.infinity,
                          fit: BoxFit.cover, // Para que llene el espacio bonito
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                              height: 150,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(
                              height: 150,
                              child: Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40))
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      "${_formatDate(r.createdAt)}"
                          "${author.isNotEmpty ? " • $author" : ""}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),

                    // ✅ Mensaje si NO es usuario
                    if (!canCreateReport) ...[
                      const SizedBox(height: 6),
                      const Text(
                        "Solo el rol Usuario puede crear reportes.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
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
