import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/quiz_model.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';

class QuizHistoryScreen extends StatefulWidget {
  const QuizHistoryScreen({super.key});

  @override
  State<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends State<QuizHistoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<QuizAttempt> _attempts = [];
  Map<String, QuizModel> _quizById = {};
  bool _isLoading = true;
  int? _selectedDifficulty;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user != null) {
        final quizzes = await _firestoreService.getQuizzes();
        final attempts = await _firestoreService.getUserQuizAttempts(user.uid);

        _quizById = {
          for (final quiz in quizzes) quiz.id: quiz,
        };
        _attempts = attempts;
      } else {
        _attempts = [];
        _quizById = {};
      }
    } catch (_) {
      _attempts = [];
      _quizById = {};
    }

    setState(() => _isLoading = false);
  }

  List<QuizAttempt> get _filteredAttempts {
    return _attempts.where((attempt) {
      final quiz = _quizById[attempt.quizId];
      if (quiz == null) return false;
      final matchesDifficulty =
          _selectedDifficulty == null || quiz.difficulty == _selectedDifficulty;
      final matchesCategory =
          _selectedCategory == null || quiz.category == _selectedCategory;
      return matchesDifficulty && matchesCategory;
    }).toList();
  }

  List<int> get _availableLevels {
    final levels = _quizById.values.map((quiz) => quiz.difficulty).toSet().toList();
    levels.sort();
    return levels;
  }

  List<String> get _availableCategories {
    final categories = _quizById.values.map((quiz) => quiz.category).toSet().toList();
    categories.sort();
    return categories;
  }

  @override
  Widget build(BuildContext context) {
    final attempts = _filteredAttempts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz History'),
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCard(attempts),
                  const SizedBox(height: 16),
                  _buildFilterRow(),
                  const SizedBox(height: 16),
                  if (attempts.isEmpty)
                    _buildEmptyState()
                  else
                    ...attempts.map(_buildAttemptCard),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(List<QuizAttempt> attempts) {
    final correct = attempts.where((a) => a.isCorrect).length;
    final accuracy = attempts.isNotEmpty ? (correct / attempts.length) * 100 : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: _buildStat('Attempts', '${attempts.length}')),
            Expanded(child: _buildStat('Correct', '$correct')),
            Expanded(child: _buildStat('Accuracy', '${accuracy.toStringAsFixed(0)}%')),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildFilterRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<int?>(
            value: _selectedDifficulty,
            decoration: const InputDecoration(
              labelText: 'Level',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('All'),
              ),
              ..._availableLevels.map(
                (level) => DropdownMenuItem<int?>(
                  value: level,
                  child: Text('Level $level'),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _selectedDifficulty = value),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String?>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Content',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All'),
              ),
              ..._availableCategories.map(
                (category) => DropdownMenuItem<String?>(
                  value: category,
                  child: Text(category),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _selectedCategory = value),
          ),
        ),
        TextButton(
          onPressed: (_selectedDifficulty == null && _selectedCategory == null)
              ? null
              : () {
                  setState(() {
                    _selectedDifficulty = null;
                    _selectedCategory = null;
                  });
                },
          child: const Text('Clear filters'),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.history_toggle_off, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No quiz history',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Quiz attempts will appear here after the user completes quizzes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAttemptCard(QuizAttempt attempt) {
    final quiz = _quizById[attempt.quizId];
    if (quiz == null) return const SizedBox.shrink();

    final selectedAnswer = attempt.selectedIndex < quiz.options.length
        ? quiz.options[attempt.selectedIndex]
        : 'Unknown';
    final correctAnswer = quiz.correctIndex < quiz.options.length
        ? quiz.options[quiz.correctIndex]
        : 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: attempt.isCorrect ? Colors.green : Colors.red,
          child: Icon(
            attempt.isCorrect ? Icons.check : Icons.close,
            color: Colors.white,
          ),
        ),
        title: Text(quiz.questionMalay),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Content: ${quiz.category}'),
            Text('Level: ${quiz.difficulty}'),
            Text('Selected: $selectedAnswer'),
            Text('Correct: $correctAnswer'),
            const SizedBox(height: 4),
            Text(DateFormat('MMM d, yyyy h:mm a').format(attempt.attemptedAt)),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
