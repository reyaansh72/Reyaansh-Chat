import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

import 'about.dart';
import 'chat.dart';
import 'filesend.dart';
import 'notes.dart';
import 'server_management.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppSelectorApp());
}

class AppSelectorApp extends StatefulWidget {
  const AppSelectorApp({super.key});

  @override
  State<AppSelectorApp> createState() => _AppSelectorAppState();
}

class _AppSelectorAppState extends State<AppSelectorApp> {
  Color _seedColor = const Color(0xFF6750A4);
  ThemeMode _themeMode = ThemeMode.light;

  void _pickColor(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Pick a Material You color'),
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

  void _randomizeColor() {
    final random = Random();
    setState(() {
      _seedColor = Color.fromARGB(
        255,
        random.nextInt(256),
        random.nextInt(256),
        random.nextInt(256),
      );
    });
  }

  void _openChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReyaanshCoreApp()),
    );
  }

  void _openDrop(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppState()),
          ],
          child: const FileTransferApp(),
        ),
      ),
    );
  }

  void _openNotes(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReyaanshNotesApp()),
    );
  }

  void _openAboutDevice(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AboutDevicePage()),
    );
  }

  void _openServerManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ServerManagementPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: _themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
    );

    return MaterialApp(
      title: 'Reyaansh Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: colorScheme),
      darkTheme: ThemeData(useMaterial3: true, colorScheme: colorScheme.copyWith(brightness: Brightness.dark)),
      themeMode: _themeMode,
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Material You App Selector'),
            actions: [
              IconButton(
                icon: const Icon(Icons.color_lens),
                tooltip: 'Pick theme color',
                onPressed: () => _pickColor(context),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to the Reyaansh All-in-One Launcher',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose an app below and customize the Material You theme color.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(backgroundColor: _seedColor, radius: 18),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Material You theme color',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.shuffle),
                                tooltip: 'Randomize color',
                                onPressed: _randomizeColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.palette),
                                label: const Text('Pick color'),
                                onPressed: () => _pickColor(context),
                              ),
                              FilledButton.icon(
                                icon: const Icon(Icons.dark_mode),
                                label: Text(_themeMode == ThemeMode.dark ? 'Dark mode' : 'Light mode'),
                                onPressed: () {
                                  setState(() {
                                    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildAppCard(
                          icon: Icons.chat_bubble_outline,
                          title: 'Reyaansh Chat',
                          subtitle: 'Open the chat experience from chat.dart',
                          onTap: () => _openChat(context),
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        _buildAppCard(
                          icon: Icons.cloud_upload_outlined,
                          title: 'Reyaansh Drop',
                          subtitle: 'Open the file sender in filesend.dart',
                          onTap: () => _openDrop(context),
                          color: colorScheme.secondary,
                        ),
                        const SizedBox(height: 16),
                        _buildAppCard(
                          icon: Icons.sticky_note_2_outlined,
                          title: 'Reyaansh Notes',
                          subtitle: 'Open the note-taking app from notes.dart',
                          onTap: () => _openNotes(context),
                          color: colorScheme.tertiary,
                        ),
                        const SizedBox(height: 16),
                        _buildAppCard(
                          icon: Icons.devices,
                          title: 'About Device',
                          subtitle: 'See hardware and platform details',
                          onTap: () => _openAboutDevice(context),
                          color: colorScheme.primaryContainer,
                        ),
                        const SizedBox(height: 16),
                        _buildAppCard(
                          icon: Icons.storage,
                          title: 'Server Management',
                          subtitle: 'Manage Firebase status and RTDB JSON',
                          onTap: () => _openServerManagement(context),
                          color: colorScheme.secondaryContainer,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Tap a tile to open the app. Use the theme controls above to preview Material You styling.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.18),
                foregroundColor: color,
                child: Icon(icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
