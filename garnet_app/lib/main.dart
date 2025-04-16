import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recipe Importer',
      theme: ThemeData(primarySwatch: Colors.deepOrange),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const RecipeUrlInputPage(),
    const RecipeListPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (int index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.link), label: 'Import URL'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Saved Recipes'),
        ],
      ),
    );
  }
}

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

    // Step 2: Save to DB
    final saveResponse = await http.post(
      Uri.parse('http://127.0.0.1:8000/recipes/save'),
      headers: {"Content-Type": "application/json"},
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

class RecipeListPage extends StatefulWidget {
  const RecipeListPage({super.key});

  @override
  State<RecipeListPage> createState() => _RecipeListPageState();
}
class RecipeDetailPage extends StatelessWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailPage({super.key, required this.recipe});

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
                Navigator.pop(context); // Go back to refresh list
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Delete Recipe"),
                  content: const Text("Are you sure you want to delete this recipe?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text("Delete"),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                final response = await http.delete(
                  Uri.parse('http://127.0.0.1:8000/recipes/${recipe["id"]}/delete'),
                  // Replace with AppConfig.apiBaseUrl if you're using config
                );

                if (response.statusCode == 200) {
                  if (context.mounted) {
                    Navigator.pop(context); // Go back after deleting
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Recipe deleted")),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to delete: ${response.statusCode}")),
                    );
                  }
                }
              }
            },
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
            Text(
              "📝 Ingredients:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            ...recipe["ingredients"].map<Widget>((item) => Text("- $item")),
            const SizedBox(height: 16),
            Text(
              "📋 Steps:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            ...recipe["steps"].map<Widget>((step) => Text("• $step")),
          ],
        ),
      ),
    );
  }
}



class _RecipeListPageState extends State<RecipeListPage> {
  late Future<List<Map<String, dynamic>>> _recipes;

  Future<List<Map<String, dynamic>>> fetchRecipes() async {
    final response = await http.get(Uri.parse('http://127.0.0.1:8000/recipes/'));

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
                    // 🔁 Refresh after returning
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

    final response = await http.put(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(updatedRecipe),
    );

    setState(() => _saving = false);

    if (response.statusCode == 200) {
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

