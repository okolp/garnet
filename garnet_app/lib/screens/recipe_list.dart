import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../auth/auth_service.dart';
import 'recipe_detail.dart';

class RecipeListPage extends StatefulWidget {
  const RecipeListPage({super.key});

  @override
  State<RecipeListPage> createState() => _RecipeListPageState();
}

class _RecipeListPageState extends State<RecipeListPage> {
  late Future<List<Map<String, dynamic>>> _recipes;

  Future<List<Map<String, dynamic>>> fetchRecipes() async {
    final token = await AuthService.getToken();

    final response = await http.get(
      Uri.parse('http://127.0.0.1:8000/recipes/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = utf8.decode(response.bodyBytes);
      final List<dynamic> data = jsonDecode(decoded);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load recipes: ${response.statusCode}');
    }
  }

  @override
  void initState() {
    super.initState();
    _recipes = fetchRecipes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Saved Recipes")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _recipes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No recipes found."));
          }

          final recipes = snapshot.data!;
          return ListView.builder(
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: recipe['image_url'] != null
                      ? Image.network(recipe['image_url'], width: 60, fit: BoxFit.cover)
                      : const Icon(Icons.image_not_supported),
                  title: Text(recipe['title'] ?? 'No title'),
                  subtitle: Text((recipe['tags'] as List).join(', ')),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailPage(recipe: recipe),
                      ),
                    );
                    setState(() {
                      _recipes = fetchRecipes();
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
