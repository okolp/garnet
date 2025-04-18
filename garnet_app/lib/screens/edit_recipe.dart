import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../auth/auth_service.dart';

class EditRecipePage extends StatefulWidget {
  final Map<String, dynamic> recipe;

  const EditRecipePage({super.key, required this.recipe});

  @override
  State<EditRecipePage> createState() => _EditRecipePageState();
}

class _EditRecipePageState extends State<EditRecipePage> {
  late TextEditingController titleController;
  late TextEditingController imageUrlController;
  late TextEditingController tagsController;

  late List<String> _ingredients;
  late List<String> _steps;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.recipe['title']);
    imageUrlController = TextEditingController(text: widget.recipe['image_url'] ?? '');
    tagsController = TextEditingController(text: (widget.recipe['tags'] as List).join(', '));

    _ingredients = List<String>.from(widget.recipe['ingredients']);
    _steps = List<String>.from(widget.recipe['steps']);
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);

    final updatedRecipe = {
      "title": titleController.text.trim(),
      "ingredients": _ingredients.where((i) => i.trim().isNotEmpty).toList(),
      "steps": _steps.where((s) => s.trim().isNotEmpty).toList(),
      "tags": tagsController.text.split(',').map((e) => e.trim()).toList(),
      "image_url": imageUrlController.text.trim(),
    };

    final url = Uri.parse('http://127.0.0.1:8000/recipes/${widget.recipe["id"]}/edit');
    final token = await AuthService.getToken();

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(updatedRecipe),
    );

    setState(() => _saving = false);

    if (response.statusCode == 200 && context.mounted) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save changes: ${response.statusCode}")),
      );
    }
  }

  Widget _buildEditableList(String label, List<String> items, void Function() onAdd, void Function(int) onRemove, void Function(int, String) onChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final value = entry.value;
          return Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: value,
                  onChanged: (val) => onChange(index, val),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle),
                onPressed: () => onRemove(index),
              ),
            ],
          );
        }),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text("Add"),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Recipe")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: "Title")),
            const SizedBox(height: 12),
            TextField(controller: imageUrlController, decoration: const InputDecoration(labelText: "Image URL")),
            const SizedBox(height: 16),

            _buildEditableList(
              "Ingredients",
              _ingredients,
              () => setState(() => _ingredients.add("")),
              (index) => setState(() => _ingredients.removeAt(index)),
              (index, val) => _ingredients[index] = val,
            ),

            _buildEditableList(
              "Steps",
              _steps,
              () => setState(() => _steps.add("")),
              (index) => setState(() => _steps.removeAt(index)),
              (index, val) => _steps[index] = val,
            ),

            TextField(
              controller: tagsController,
              decoration: const InputDecoration(labelText: "Tags (comma separated)"),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _saveChanges,
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}
