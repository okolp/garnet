import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../auth/auth_service.dart';
import 'home_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);

    final resp = await http.post(
      Uri.parse('http://127.0.0.1:8000/auth/login'),
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: {
        "username": _emailController.text.trim(),
        "password": _passwordController.text.trim(),
      },
    );
    setState(() => _loading = false);

    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      final token = body["access_token"] as String;
      await AuthService.saveToken(token);

      // ---- fetch profile ----
      final me = await http.get(
        Uri.parse('http://127.0.0.1:8000/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (me.statusCode == 200) {
        final data = jsonDecode(me.body);
        final lang = data['preferred_language'] as String? ?? 'English';
        await AuthService.savePreferredLanguage(lang);
      }
      // -----------------------

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: ${resp.statusCode}")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Login"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/register');
              },
              child: const Text("Don't have an account? Register"),
            ),
          ],
        ),
      ),
    );
  }
}
