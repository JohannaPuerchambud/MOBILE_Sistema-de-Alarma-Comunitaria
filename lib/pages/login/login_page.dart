import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/token_storage.dart';
import '../home/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _storage = TokenStorage();

  bool loading = false;

  Future<void> login() async {
    setState(() => loading = true);

    final token = await _authService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      // Guardamos el token de forma segura
      await _storage.saveToken(token);

      if (!mounted) return;

      // ✅ Aquí está el cambio: Limpiamos todo el historial de navegación
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomePage()),
            (route) => false, // Al devolver false, eliminamos todas las rutas previas
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credenciales incorrectas ❌')),
      );
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alarma Comunitaria')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : login,
              child: Text(loading ? 'Ingresando...' : 'Ingresar'),
            )
          ],
        ),
      ),
    );
  }
}
