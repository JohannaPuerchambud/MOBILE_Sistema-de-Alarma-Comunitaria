import 'package:flutter/material.dart';
import '../../core/auth/token_storage.dart';
import '../../features/reports/report_list_page.dart';
import '../login/login_page.dart';
import '../../features/chat/chat_page.dart';


class HomePage extends StatelessWidget {
  HomePage({super.key});

  final storage = TokenStorage();

  Future<void> logout(BuildContext context) async {
    await storage.clearToken();
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            tooltip: 'Salir',
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.report),
                label: const Text('Reportes del barrio'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportListPage()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat),
                label: const Text('Chat barrial'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatPage()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
