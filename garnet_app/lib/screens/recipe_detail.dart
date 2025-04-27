import 'package:flutter/material.dart';

class RecipeDetailPage extends StatefulWidget {
  final Map<String, dynamic> recipe;
  const RecipeDetailPage({super.key, required this.recipe});

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  late List<String> _ingredients;
  late List<bool> _ingChecks;
  late List<String> _steps;
  late List<bool> _stepChecks;

  @override
  void initState() {
    super.initState();
    // Extract ingredients and steps from the recipe map
    _ingredients = List<String>.from(widget.recipe['ingredients'] ?? []);
    _ingChecks = List<bool>.filled(_ingredients.length, false);
    _steps = List<String>.from(widget.recipe['steps'] ?? []);
    _stepChecks = List<bool>.filled(_steps.length, false);
  }

  /// Resets all checkboxes to unchecked
  void _resetChecks() {
    setState(() {
      _ingChecks = List<bool>.filled(_ingredients.length, false);
      _stepChecks = List<bool>.filled(_steps.length, false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe['title'] ?? 'Recipe Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recipe Image
              if (widget.recipe['image_url'] != null)
                Image.network(
                  widget.recipe['image_url'],
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              const SizedBox(height: 16),

              // Ingredients Section
              const Text(
                'Ingredients',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Start Cooking Again Button (moved above checkboxes)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _resetChecks,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Start Cooking Again'),
                ),
              ),
              const SizedBox(height: 16),

              // Ingredient Checkboxes
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _ingredients.length,
                itemBuilder: (context, index) {
                  return CheckboxListTile(
                    title: Text(_ingredients[index]),
                    value: _ingChecks[index],
                    onChanged: (checked) {
                      setState(() {
                        _ingChecks[index] = checked ?? false;
                      });
                    },
                  );
                },
              ),

              const Divider(height: 32),

              // Steps Section
              const Text(
                'Steps',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Step Checkboxes
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  return CheckboxListTile(
                    title: Text('${index + 1}. ${_steps[index]}'),
                    value: _stepChecks[index],
                    onChanged: (checked) {
                      setState(() {
                        _stepChecks[index] = checked ?? false;
                      });
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
