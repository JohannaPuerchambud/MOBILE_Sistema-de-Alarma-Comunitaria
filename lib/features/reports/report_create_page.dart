import 'package:flutter/material.dart';
import 'report_service.dart';

class ReportCreatePage extends StatefulWidget {
  const ReportCreatePage({super.key});

  @override
  State<ReportCreatePage> createState() => _ReportCreatePageState();
}

class _ReportCreatePageState extends State<ReportCreatePage> {
  final _service = ReportService();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool loading = false;
  String? error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      setState(() => error = "Completa título y descripción.");
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await _service.createReport(title: title, description: desc);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reporte enviado ✅")),
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nuevo reporte")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: "Título",
                hintText: "Ej: Robo / Sospechoso / Ruido / Emergencia",
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: "Descripción",
                hintText: "Describe lo ocurrido…",
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: loading ? null : _submit,
                child: Text(loading ? "Enviando..." : "Enviar reporte"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
