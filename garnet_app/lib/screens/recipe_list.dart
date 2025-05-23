// lib/pages/recipe_list_page.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_service.dart';
import '../utils/tags_by_language.dart';
import 'recipe_detail.dart';

class RecipeListPage extends StatefulWidget {
  const RecipeListPage({super.key});

  @override
  State<RecipeListPage> createState() => _RecipeListPageState();
}

class _RecipeListPageState extends State<RecipeListPage> {
  // populated in initState based on user’s language
  late final List<String> _allTags;
  final Set<String> _selectedTags = {};

  // search state
  String _searchQuery = '';
  Timer? _debounce;

  late Future<List<Map<String, dynamic>>> _recipesFuture;

  @override
  void initState() {
    super.initState();
    // pick translated tags for this user
    final lang = AuthService.getPreferredLanguage();
    _allTags = tagsByLanguage[lang] ?? tagsByLanguage['English']!;
    _recipesFuture = fetchRecipes();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> fetchRecipes() async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('http://127.0.0.1:8000/recipes/').replace(
      queryParameters: {
        if (_searchQuery.isNotEmpty) 'q': _searchQuery,
        ...Map.fromEntries(_selectedTags.map((t) => MapEntry('tags', t))),
      },
    );

    final response = await http.get(
      uri,
      headers: { 'Authorization': 'Bearer $token' },
    );

    if (response.statusCode == 200) {
      final decoded = utf8.decode(response.bodyBytes);
      final List<dynamic> data = jsonDecode(decoded);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load recipes: ${response.statusCode}');
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = val;
        _recipesFuture = fetchRecipes();
      });
    });
  }

  void _onTagTapped(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
      _recipesFuture = fetchRecipes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Saved Recipes")),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search recipes...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Tag filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: _allTags.map((tag) {
                final selected = _selectedTags.contains(tag);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (_) => _onTagTapped(tag),
                  ),
                );
              }).toList(),
            ),
          ),

          // Recipe list
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _recipesFuture,
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
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: recipe['image_url'] != null
                            ? Image.network(
                                recipe['image_url'],
                                width: 60,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.image_not_supported),
                        title: Text(recipe['title'] ?? 'No title'),
                        subtitle: Text((recipe['tags'] as List).join(', ')),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RecipeDetailPage(recipe: recipe),
                            ),
                          );
                          setState(() {
                            _recipesFuture = fetchRecipes();
                          });
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
