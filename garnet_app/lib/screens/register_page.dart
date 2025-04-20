import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../auth/auth_service.dart';
import 'home_screen.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;

  String _selectedLanguage = 'English';
  String _selectedUnits = 'metric';

  final List<String> _languages = [
    'English', 'German', 'Spanish', 'French', 'Dutch', 'Polish', 'Turkish'
  ];

  final List<String> _units = ['metric', 'imperial'];

  Future<void> _register() async {
    setState(() => _loading = true);

    final response = await http.post(
      Uri.parse('http://127.0.0.1:8000/auth/register'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": _emailController.text.trim(),
        "password": _passwordController.text.trim(),
        "preferred_language": _selectedLanguage,
        "preferred_units": _selectedUnits,
      }),
    );

    setState(() => _loading = false);

    if (response.statusCode == 200) {
      final token = jsonDecode(response.body)["access_token"];
      await AuthService.saveToken(token);

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registration failed: ${response.statusCode}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
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
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedLanguage,
              items: _languages
                  .map((lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(lang),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedLanguage = val!),
              decoration: const InputDecoration(labelText: "Preferred Language"),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedUnits,
              items: _units
                  .map((unit) => DropdownMenuItem(
                        value: unit,
                        child: Text(unit == 'metric' ? 'Metric (g, ml)' : 'Imperial (oz, cups)'),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedUnits = val!),
              decoration: const InputDecoration(labelText: "Measurement System"),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _register,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Create Account"),
            ),
          ],
        ),
      ),
    );
  }
}
