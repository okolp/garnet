import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../auth/auth_service.dart';

class RecipeUrlInputPage extends StatefulWidget {
  const RecipeUrlInputPage({super.key});

  @override
  State<RecipeUrlInputPage> createState() => _RecipeUrlInputPageState();
}

class _RecipeUrlInputPageState extends State<RecipeUrlInputPage> {
  final TextEditingController _urlController = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _recipe;

  Future<void> _submitUrl() async {
    setState(() {
      _loading = true;
      _recipe = null;
    });

    final url = Uri.parse('http://127.0.0.1:8000/recipes/from-url');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"url": _urlController.text}),
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(decodedBody);
      final recipe = data['recipe'];

      final token = await AuthService.getToken();
      final saveResponse = await http.post(
        Uri.parse('http://127.0.0.1:8000/recipes/save'),
        headers: {
          "Content-Type": "application/json",
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(recipe),
      );

      if (saveResponse.statusCode == 200) {
        final saveResult = jsonDecode(saveResponse.body);
        print("✅ Saved recipe with ID: ${saveResult["id"]}");
      } else {
        print("❌ Failed to save recipe: ${saveResponse.statusCode}");
      }

      setState(() {
        _recipe = recipe;
      });
    } else {
      setState(() {
        _recipe = {"error": "Failed: ${response.statusCode}\n${response.body}"};
      });
    }

    setState(() {
      _loading = false;
    });
  }

  Widget _buildRecipeDetails() {
    if (_recipe == null) return const SizedBox();
    if (_recipe!.containsKey("error")) {
      return Text(_recipe!["error"], style: const TextStyle(color: Colors.red));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("🍽 Title: ${_recipe!["title"]}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text("🏷 Tags: ${(_recipe!["tags"] as List).join(', ')}"),
        const SizedBox(height: 10),
        Text("📝 Ingredients:\n${(_recipe!["ingredients"] as List).join('\n')}"),
        const SizedBox(height: 10),
        Text("📋 Steps:\n${(_recipe!["steps"] as List).join('\n')}"),
        const SizedBox(height: 10),
        _recipe!["image_url"] != null
            ? Image.network(_recipe!["image_url"], height: 150)
            : const Text("No image provided"),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Import Recipe from URL")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: "Paste Recipe URL",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _loading ? null : _submitUrl,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Fetch Recipe"),
            ),
            const SizedBox(height: 20),
            Expanded(child: SingleChildScrollView(child: _buildRecipeDetails())),
          ],
        ),
      ),
    );
  }
}
