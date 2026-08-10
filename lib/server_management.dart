import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:http/http.dart' as http;

import 'firebase_options.dart';

class ServerManagementPage extends StatefulWidget {
  const ServerManagementPage({super.key});

  @override
  State<ServerManagementPage> createState() => _ServerManagementPageState();
}

class _ServerManagementPageState extends State<ServerManagementPage> {
  bool _loading = true;
  String _firebaseStatus = 'Unknown';
  String _firebaseUrl = 'Unknown';
  String _githubStatus = 'Unknown';
  String _githubForks = 'Unknown';
  String _githubWatchers = 'Unknown';
  String _githubOpenIssues = 'Unknown';
  String _githubRepoSize = 'Unknown';
  String _databaseJson = '{}';
  String _jsonSize = '0';
  int _jsonKeys = 0;
  Color _seedColor = const Color(0xFF6750A4);
  ThemeMode _themeMode = ThemeMode.light;
  final TextEditingController _jsonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      final ref = FirebaseDatabase.instance.ref();
      final snapshot = await ref.get();
      final value = snapshot.value ?? {};
      _databaseJson = const JsonEncoder.withIndent('  ').convert(value);
      _jsonController.text = _databaseJson;
      _jsonSize = '${_databaseJson.length} bytes';
      _jsonKeys = value is Map ? value.length : 0;
      _firebaseStatus = 'Available';
    } catch (error) {
      _firebaseStatus = 'Unavailable: $error';
    }

    try {
      final response = await http.get(Uri.parse('https://api.github.com/repos/Reyaansh-Chat'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _githubStatus = 'OK: ${data['stargazers_count']} stars';
        _githubForks = '${data['forks_count']}';
        _githubWatchers = '${data['watchers_count']}';
        _githubOpenIssues = '${data['open_issues_count']}';
        _githubRepoSize = '${data['size']} KB';
      } else {
        _githubStatus = 'GitHub API error: ${response.statusCode}';
      }
    } catch (error) {
      _githubStatus = 'Failed to fetch GitHub: $error';
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _pickThemeColor(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Pick Material You color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _seedColor,
              onColorChanged: (color) => setState(() => _seedColor = color),
              labelTypes: const [],
              pickerAreaHeightPercent: 0.6,
              enableAlpha: false,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _toggleThemeMode() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _pushJsonToFirebase() async {
    try {
      final decoded = jsonDecode(_jsonController.text);
      final ref = FirebaseDatabase.instance.ref();
      await ref.set(decoded);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON pushed to Firebase.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Push failed: $error')));
    }
  }

  Future<void> _publishNoteToFirebase(String title, String content) async {
    try {
      final notesRef = FirebaseDatabase.instance.ref('notes').push();
      await notesRef.set({
        'title': title,
        'content': content,
        'publishedAt': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note published to Firebase.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publish failed: $error')));
    }
  }

  void _showPublishNoteDialog() {
    final titleController = TextEditingController(text: 'Reyaansh Note ${DateTime.now().millisecondsSinceEpoch}');
    final contentController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Publish Note'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(labelText: 'Note content'),
                  minLines: 4,
                  maxLines: 8,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final content = contentController.text.trim();
                if (title.isEmpty || content.isEmpty) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                _publishNoteToFirebase(title, content);
              },
              child: const Text('Publish'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: _themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
      ),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Server Management'),
          actions: [
            IconButton(
              icon: const Icon(Icons.color_lens),
              tooltip: 'Pick theme color',
              onPressed: () => _pickThemeColor(context),
            ),
            IconButton(
              icon: Icon(_themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
              tooltip: 'Toggle theme mode',
              onPressed: _toggleThemeMode,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Firebase status: $_firebaseStatus', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Database URL: $_firebaseUrl', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    const Text('GitHub repository', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Status: $_githubStatus', style: Theme.of(context).textTheme.bodyLarge),
                    Text('Forks: $_githubForks', style: Theme.of(context).textTheme.bodyMedium),
                    Text('Watchers: $_githubWatchers', style: Theme.of(context).textTheme.bodyMedium),
                    Text('Open issues: $_githubOpenIssues', style: Theme.of(context).textTheme.bodyMedium),
                    Text('Repo size: $_githubRepoSize', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    const Text('Realtime Database JSON', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        controller: _jsonController,
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        expands: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Edit Firebase RTDB JSON here',
                        ),
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('JSON size: $_jsonSize', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Text('Top-level keys: $_jsonKeys', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text('PUSH JSON'),
                          onPressed: _pushJsonToFirebase,
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.publish),
                          label: const Text('Publish note'),
                          onPressed: _showPublishNoteDialog,
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh status'),
                          onPressed: _loadStatus,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
