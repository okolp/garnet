import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import 'edit_recipe.dart';

typedef Recipe = Map<String, dynamic>;

class RecipeDetailPage extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailPage({super.key, required this.recipe});

  Future<void> _deleteRecipe(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Recipe"),
        content: const Text("Are you sure you want to delete this recipe?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirm == true) {
      final token = await AuthService.getToken();
      final response = await http.delete(
        Uri.parse('http://127.0.0.1:8000/recipes/${recipe["id"]}/delete'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 && context.mounted) {
        Navigator.pop(context); // Go back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Recipe deleted")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete: ${response.statusCode}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe["title"] ?? "Recipe Detail"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditRecipePage(recipe: recipe),
                ),
              );
              if (updated == true && context.mounted) {
                Navigator.pop(context); // Return to refresh list
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteRecipe(context),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            recipe["image_url"] != null
                ? Image.network(recipe["image_url"], height: 180)
                : const Text("No image provided"),
            const SizedBox(height: 16),
            Text("🏷 Tags: ${recipe["tags"].join(', ')}"),
            const SizedBox(height: 16),
            Text("📝 Ingredients:", style: const TextStyle(fontWeight: FontWeight.bold)),
            ...recipe["ingredients"].map<Widget>((item) => Text("- $item")),
            const SizedBox(height: 16),
            Text("📋 Steps:", style: const TextStyle(fontWeight: FontWeight.bold)),
            ...recipe["steps"].map<Widget>((step) => Text("• $step")),
          ],
        ),
      ),
    );
  }
}
