import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../auth/auth_service.dart';

class RecipeImageInputPage extends StatefulWidget {
  const RecipeImageInputPage({super.key});

  @override
  State<RecipeImageInputPage> createState() => _RecipeImageInputPageState();
}

class _RecipeImageInputPageState extends State<RecipeImageInputPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  bool _loading = false;
  Map<String, dynamic>? _recipe;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = image;
        _recipe = null;
      });
    }
  }

  Future<void> _submitImage() async {
    if (_imageFile == null) return;
    setState(() {
      _loading = true;
      _recipe = null;
    });
    final token = await AuthService.getToken();
    final uri = Uri.parse('http://127.0.0.1:8000/recipes/from-image');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      _imageFile!.path,
      filename: _imageFile!.name,
    ));

    try {
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _recipe = data['recipe'];
        });
      } else {
        setState(() {
          _recipe = {
            'error': 'Failed: ${response.statusCode}\n${response.body}'
          };
        });
      }
    } catch (e) {
      setState(() {
        _recipe = {'error': e.toString()};
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _buildRecipeDetails() {
    if (_recipe == null) return const SizedBox();
    if (_recipe!.containsKey('error')) {
      return Text(
        _recipe!['error'],
        style: const TextStyle(color: Colors.red),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "🍽 Title: ${_recipe!['title']}",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text("🏷 Tags: ${(_recipe!['tags'] as List).join(', ')}"),
        const SizedBox(height: 10),
        Text("📝 Ingredients:\n${(_recipe!['ingredients'] as List).join('\n')}"),
        const SizedBox(height: 10),
        Text("📋 Steps:\n${(_recipe!['steps'] as List).join('\n')}"),
        const SizedBox(height: 10),
        _recipe!['image_url'] != null
            ? Image.network(_recipe!['image_url'], height: 150)
            : const Text("No image provided"),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Import Recipe from Photo")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _loading ? null : _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text("Select Photo"),
            ),
            const SizedBox(height: 10),
            if (_imageFile != null)
              Image.file(File(_imageFile!.path), height: 200),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: (_loading || _imageFile == null) ? null : _submitImage,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt),
              label: const Text("Analyze Photo"),
            ),
            const SizedBox(height: 20),
            Expanded(child: SingleChildScrollView(child: _buildRecipeDetails())),
          ],
        ),
      ),
    );
  }
}
