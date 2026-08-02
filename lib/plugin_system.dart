import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PluginDefinition {
  final String id;
  final String name;
  final String description;
  final String author;
  final String category;
  final String seedColorHex;
  final String accentColorHex;
  final int cardRadius;
  final double spacingMultiplier;
  final bool useGlassMorphism;
  final bool useRoundedCorners;
  final String previewTag;
  final bool isBuiltIn;
  final String sourceCode;
  final bool canModifyChatLogic;
  final bool canModifyChatUi;
  final bool canAddCommands;
  final bool canAddPages;
  final bool canAddWidgets;
  final String runtimeHints;
  final List<String> pageNames;
  final List<String> widgetLabels;

  const PluginDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.author,
    required this.category,
    required this.seedColorHex,
    required this.accentColorHex,
    required this.cardRadius,
    required this.spacingMultiplier,
    required this.useGlassMorphism,
    required this.useRoundedCorners,
    required this.previewTag,
    this.isBuiltIn = false,
    this.sourceCode = '',
    this.canModifyChatLogic = false,
    this.canModifyChatUi = false,
    this.canAddCommands = false,
    this.canAddPages = false,
    this.canAddWidgets = false,
    this.runtimeHints = '',
    this.pageNames = const <String>[],
    this.widgetLabels = const <String>[],
  });

  factory PluginDefinition.fromJson(Map<String, dynamic> json) {
    return PluginDefinition(
      id: json['id']?.toString() ?? 'plugin',
      name: json['name']?.toString() ?? 'Untitled Plugin',
      description: json['description']?.toString() ?? '',
      author: json['author']?.toString() ?? 'Unknown',
      category: json['category']?.toString() ?? 'ui',
      seedColorHex: json['seedColorHex']?.toString() ?? '#2e9a7c',
      accentColorHex: json['accentColorHex']?.toString() ?? '#ffffff',
      cardRadius: int.tryParse(json['cardRadius']?.toString() ?? '') ?? 18,
      spacingMultiplier: double.tryParse(json['spacingMultiplier']?.toString() ?? '') ?? 1.0,
      useGlassMorphism: json['useGlassMorphism'] == true,
      useRoundedCorners: json['useRoundedCorners'] != false,
      previewTag: json['previewTag']?.toString() ?? 'preview',
      isBuiltIn: json['isBuiltIn'] == true,
      sourceCode: json['sourceCode']?.toString() ?? '',
      canModifyChatLogic: json['canModifyChatLogic'] == true,
      canModifyChatUi: json['canModifyChatUi'] == true,
      canAddCommands: json['canAddCommands'] == true,
      canAddPages: json['canAddPages'] == true,
      canAddWidgets: json['canAddWidgets'] == true,
      runtimeHints: json['runtimeHints']?.toString() ?? '',
      pageNames: (json['pageNames'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const <String>[],
      widgetLabels: (json['widgetLabels'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const <String>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'author': author,
      'category': category,
      'seedColorHex': seedColorHex,
      'accentColorHex': accentColorHex,
      'cardRadius': cardRadius,
      'spacingMultiplier': spacingMultiplier,
      'useGlassMorphism': useGlassMorphism,
      'useRoundedCorners': useRoundedCorners,
      'previewTag': previewTag,
      'isBuiltIn': isBuiltIn,
      'sourceCode': sourceCode,
      'canModifyChatLogic': canModifyChatLogic,
      'canModifyChatUi': canModifyChatUi,
      'canAddCommands': canAddCommands,
      'canAddPages': canAddPages,
      'canAddWidgets': canAddWidgets,
      'runtimeHints': runtimeHints,
      'pageNames': pageNames,
      'widgetLabels': widgetLabels,
    };
  }

  Color get seedColor => _parseHex(seedColorHex);

  Color get accentColor => _parseHex(accentColorHex);

  static Color _parseHex(String hex) {
    final sanitized = hex.trim().replaceFirst('#', '');
    final normalized = sanitized.length == 6 ? 'FF$sanitized' : sanitized;
    return Color(int.parse(normalized, radix: 16));
  }

  String toDartSource() {
    return '''
import 'package:chat/plugin_system.dart';

final plugin = PluginDefinition(
  id: '$id',
  name: '$name',
  description: '$description',
  author: '$author',
  category: '$category',
  seedColorHex: '$seedColorHex',
  accentColorHex: '$accentColorHex',
  cardRadius: $cardRadius,
  spacingMultiplier: $spacingMultiplier,
  useGlassMorphism: $useGlassMorphism,
  useRoundedCorners: $useRoundedCorners,
  previewTag: '$previewTag',
);
'''.trim();
  }

  static PluginDefinition? parsePluginDefinitionFromDartSource(String source) {
    try {
      final id = _extractString(source, 'id:');
      final name = _extractString(source, 'name:');
      final description = _extractString(source, 'description:');
      final author = _extractString(source, 'author:');
      final category = _extractString(source, 'category:');
      final seedColorHex = _extractString(source, 'seedColorHex:');
      final accentColorHex = _extractString(source, 'accentColorHex:');
      final cardRadius = _extractInt(source, 'cardRadius:');
      final spacingMultiplier = _extractDouble(source, 'spacingMultiplier:');
      final useGlassMorphism = _extractBool(source, 'useGlassMorphism:');
      final useRoundedCorners = _extractBool(source, 'useRoundedCorners:');
      final previewTag = _extractString(source, 'previewTag:');

      if (id == null || name == null || seedColorHex == null || accentColorHex == null) {
        return null;
      }

      return PluginDefinition(
        id: id,
        name: name,
        description: description ?? 'Imported plugin',
        author: author ?? 'Community',
        category: category ?? 'ui',
        seedColorHex: seedColorHex,
        accentColorHex: accentColorHex,
        cardRadius: cardRadius ?? 18,
        spacingMultiplier: spacingMultiplier ?? 1.0,
        useGlassMorphism: useGlassMorphism ?? false,
        useRoundedCorners: useRoundedCorners ?? true,
        previewTag: previewTag ?? 'imported',
        sourceCode: source,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _extractString(String source, String fieldName) {
    final regex = RegExp(r"""$fieldName\s*'([^']*)'""", caseSensitive: false);
    final match = regex.firstMatch(source);
    return match?.group(1);
  }

  static int? _extractInt(String source, String fieldName) {
    final regex = RegExp(r'''$fieldName\s*(\d+)''', caseSensitive: false);
    final match = regex.firstMatch(source);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static double? _extractDouble(String source, String fieldName) {
    final regex = RegExp(r'''$fieldName\s*([0-9.]+)''', caseSensitive: false);
    final match = regex.firstMatch(source);
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  static bool? _extractBool(String source, String fieldName) {
    final regex = RegExp(r'''$fieldName\s*(true|false)''', caseSensitive: false);
    final match = regex.firstMatch(source);
    return match == null ? null : match.group(1)!.toLowerCase() == 'true';
  }
}

class PluginManager {
  static late SharedPreferences _prefs;
  static final ValueNotifier<List<PluginDefinition>> catalogNotifier =
      ValueNotifier<List<PluginDefinition>>(<PluginDefinition>[]);
  static final ValueNotifier<PluginDefinition?> activePluginNotifier =
      ValueNotifier<PluginDefinition?>(null);

  static List<PluginDefinition> get builtInPlugins => <PluginDefinition>[
        const PluginDefinition(
          id: 'midnight_glow',
          name: 'Midnight Glow',
          description: 'A moody glassy theme with electric highlights.',
          author: 'Reyaansh',
          category: 'ui',
          seedColorHex: '#7c3aed',
          accentColorHex: '#22d3ee',
          cardRadius: 24,
          spacingMultiplier: 1.2,
          useGlassMorphism: true,
          useRoundedCorners: true,
          previewTag: 'midnight',
          isBuiltIn: true,
          canModifyChatLogic: true,
          canModifyChatUi: true,
          canAddCommands: true,
          canAddPages: true,
          canAddWidgets: true,
          runtimeHints: 'Adds a sparkle boost and command support',
          pageNames: <String>['Spark page'],
          widgetLabels: <String>['Spark button'],
        ),
        const PluginDefinition(
          id: 'mint_pop',
          name: 'Mint Pop',
          description: 'Fresh, rounded, optimistic UI for playful chats.',
          author: 'Reyaansh',
          category: 'ui',
          seedColorHex: '#34d399',
          accentColorHex: '#0f172a',
          cardRadius: 16,
          spacingMultiplier: 1.0,
          useGlassMorphism: false,
          useRoundedCorners: true,
          previewTag: 'mint',
          isBuiltIn: true,
          canModifyChatLogic: false,
          canModifyChatUi: true,
          canAddCommands: false,
          canAddPages: false,
          canAddWidgets: true,
          runtimeHints: 'Softens cards and spacing',
          widgetLabels: <String>['Mint card'],
        ),
        const PluginDefinition(
          id: 'sunset_burst',
          name: 'Sunset Burst',
          description: 'Warm, energetic cards and bold color contrast.',
          author: 'Reyaansh',
          category: 'ui',
          seedColorHex: '#f97316',
          accentColorHex: '#fb923c',
          cardRadius: 20,
          spacingMultiplier: 1.1,
          useGlassMorphism: true,
          useRoundedCorners: true,
          previewTag: 'sunset',
          isBuiltIn: true,
          canModifyChatLogic: true,
          canModifyChatUi: true,
          canAddCommands: false,
          canAddPages: true,
          canAddWidgets: true,
          runtimeHints: 'Adds warm chat accents',
          pageNames: <String>['Sunset feed'],
          widgetLabels: <String>['Sunset chip'],
        ),
      ];

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadCatalog();
  }

  static Future<void> _loadCatalog() async {
    final savedJson = _prefs.getString('plugin_catalog');
    final savedPluginId = _prefs.getString('active_plugin_id');
    final localPlugins = <PluginDefinition>[];

    if (savedJson != null && savedJson.isNotEmpty) {
      final decoded = jsonDecode(savedJson) as List<dynamic>;
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          localPlugins.add(PluginDefinition.fromJson(item));
        } else if (item is Map) {
          localPlugins.add(PluginDefinition.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    if (localPlugins.isEmpty) {
      localPlugins.addAll(builtInPlugins);
    } else {
      final merged = <String, PluginDefinition>{};
      for (final plugin in builtInPlugins) {
        merged[plugin.id] = plugin;
      }
      for (final plugin in localPlugins) {
        merged[plugin.id] = plugin;
      }
      localPlugins
        ..clear()
        ..addAll(merged.values);
    }

    catalogNotifier.value = localPlugins;

    if (savedPluginId != null && savedPluginId.isNotEmpty) {
      final found = localPlugins.where((plugin) => plugin.id == savedPluginId).firstOrNull;
      activePluginNotifier.value = found;
    } else {
      activePluginNotifier.value = null;
    }
  }

  static Future<void> saveCatalog() async {
    final payload = catalogNotifier.value.map((plugin) => plugin.toJson()).toList();
    await _prefs.setString('plugin_catalog', jsonEncode(payload));
  }

  static Future<void> addOrUpdatePlugin(PluginDefinition plugin) async {
    final current = List<PluginDefinition>.from(catalogNotifier.value);
    final index = current.indexWhere((entry) => entry.id == plugin.id);
    if (index >= 0) {
      current[index] = plugin;
    } else {
      current.add(plugin);
    }
    current.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    catalogNotifier.value = current;
    await saveCatalog();
  }

  static Future<void> importPluginFromDartSource(String source) async {
    final parsed = PluginDefinition.parsePluginDefinitionFromDartSource(source);
    if (parsed == null) {
      throw const FormatException('The plugin file does not contain a valid PluginDefinition.');
    }
    await addOrUpdatePlugin(parsed);
  }

  static Future<void> importPluginFromFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['dart'],
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    if (file.path != null && file.path!.isNotEmpty) {
      final source = await File(file.path!).readAsString();
      await importPluginFromDartSource(source);
      return;
    }

    if (file.bytes != null) {
      final source = utf8.decode(file.bytes!);
      await importPluginFromDartSource(source);
    }
  }

  static Future<void> applyPlugin(PluginDefinition? plugin) async {
    activePluginNotifier.value = plugin;
    if (plugin == null) {
      await _prefs.remove('active_plugin_id');
      return;
    }
    await _prefs.setString('active_plugin_id', plugin.id);
  }

  static Future<void> publishPluginToFirebase(PluginDefinition plugin) async {
    await FirebaseDatabase.instance.ref('plugin_store/${plugin.id}').set(plugin.toJson());
  }

  static List<PluginDefinition> getEnabledPlugins() {
    return catalogNotifier.value.where((plugin) => plugin.canModifyChatLogic || plugin.canModifyChatUi || plugin.canAddCommands || plugin.canAddPages || plugin.canAddWidgets).toList();
  }

  static List<PluginDefinition> getPagePlugins() {
    return catalogNotifier.value.where((plugin) => plugin.canAddPages && plugin.pageNames.isNotEmpty).toList();
  }

  static List<PluginDefinition> getWidgetPlugins() {
    return catalogNotifier.value.where((plugin) => plugin.canAddWidgets && plugin.widgetLabels.isNotEmpty).toList();
  }

  static String processMessageText(String input) {
    var output = input;
    for (final plugin in getEnabledPlugins()) {
      if (plugin.canModifyChatLogic) {
        output = output.replaceAll('hello', 'hello ✨');
      }
      if (plugin.canAddCommands && plugin.runtimeHints.contains('command')) {
        output = output.replaceAll('/echo', '/echo');
      }
    }
    return output;
  }

  static Map<String, dynamic> buildChatUiHints() {
    final hints = <String, dynamic>{'bubbleRadius': 18, 'showBadge': false};
    for (final plugin in getEnabledPlugins()) {
      if (plugin.canModifyChatUi) {
        hints['bubbleRadius'] = plugin.cardRadius;
        hints['showBadge'] = true;
        hints['accentColor'] = plugin.accentColorHex;
        hints['spacingMultiplier'] = plugin.spacingMultiplier;
      }
    }
    return hints;
  }

  static Widget buildPluginPagePreview(BuildContext context, {String? title}) {
    final plugins = getPagePlugins();
    if (plugins.isEmpty) {
      return const SizedBox.shrink();
    }
    final plugin = plugins.first;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title ?? plugin.pageNames.first, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(plugin.description),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: plugin.widgetLabels.map((label) => Chip(label: Text(label))).toList(),
            ),
          ],
        ),
      ),
    );
  }

  static Future<List<PluginDefinition>> fetchPluginStoreFromFirebase() async {
    final snapshot = await FirebaseDatabase.instance.ref('plugin_store').get();
    if (!snapshot.exists || snapshot.value == null) {
      return <PluginDefinition>[];
    }

    final data = snapshot.value;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((entry) => PluginDefinition.fromJson(Map<String, dynamic>.from(entry)))
          .toList();
    }

    if (data is Map) {
      return data.entries
          .map((entry) => PluginDefinition.fromJson(Map<String, dynamic>.from(entry.value as Map)))
          .toList();
    }
    return <PluginDefinition>[];
  }

  static PluginDefinition? getActivePlugin() => activePluginNotifier.value;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class PluginGuideScreen extends StatelessWidget {
  const PluginGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plugin Guide')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Build plugins like a tiny UI spellbook', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Create a .dart file with a PluginDefinition object. The app will parse it, save it locally, and optionally publish it to Firebase.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText('''
import 'package:chat/plugin_system.dart';

final plugin = PluginDefinition(
  id: 'neon_party',
  name: 'Neon Party',
  description: 'A playful glowing theme',
  author: 'You',
  category: 'ui',
  seedColorHex: '#ff4ecd',
  accentColorHex: '#00e5ff',
  cardRadius: 24,
  spacingMultiplier: 1.2,
  useGlassMorphism: true,
  useRoundedCorners: true,
  previewTag: 'neon',
);
'''),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: const [
                Chip(label: Text('Import .dart files')),
                Chip(label: Text('Publish to Firebase')),
                Chip(label: Text('Use templates')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PluginStoreScreen extends StatefulWidget {
  const PluginStoreScreen({super.key});

  @override
  State<PluginStoreScreen> createState() => _PluginStoreScreenState();
}

class _PluginStoreScreenState extends State<PluginStoreScreen> {
  late Future<List<PluginDefinition>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadStore();
  }

  Future<List<PluginDefinition>> _loadStore() async {
    final localPlugins = List<PluginDefinition>.from(PluginManager.catalogNotifier.value);
    final remotePlugins = await PluginManager.fetchPluginStoreFromFirebase();
    final merged = <String, PluginDefinition>{};
    for (final plugin in localPlugins) {
      merged[plugin.id] = plugin;
    }
    for (final plugin in remotePlugins) {
      merged[plugin.id] = plugin;
    }
    return merged.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plugin Store')),
      body: FutureBuilder<List<PluginDefinition>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final plugins = snapshot.data ?? <PluginDefinition>[];
          if (plugins.isEmpty) {
            return const Center(child: Text('No plugins yet. Create one and publish it!'));
          }
          return ListView.builder(
            itemCount: plugins.length,
            itemBuilder: (context, index) {
              final plugin = plugins[index];
              return Card(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: plugin.seedColor, child: Text(plugin.previewTag.substring(0, 1).toUpperCase())),
                  title: Text(plugin.name),
                  subtitle: Text('${plugin.description}\nby ${plugin.author} • ${plugin.category}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.download_done),
                    onPressed: () async {
                      await PluginManager.applyPlugin(plugin);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${plugin.name} applied')));
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PluginEditorScreen extends StatefulWidget {
  const PluginEditorScreen({super.key});

  @override
  State<PluginEditorScreen> createState() => _PluginEditorScreenState();
}

class _PluginEditorScreenState extends State<PluginEditorScreen> {
  final _idController = TextEditingController(text: 'custom_plugin');
  final _nameController = TextEditingController(text: 'Custom Glow');
  final _descriptionController = TextEditingController(text: 'A handcrafted UI plugin');
  final _authorController = TextEditingController(text: 'You');
  final _categoryController = TextEditingController(text: 'ui');
  final _seedColorController = TextEditingController(text: '#7c3aed');
  final _accentColorController = TextEditingController(text: '#22d3ee');
  final _radiusController = TextEditingController(text: '20');
  final _spacingController = TextEditingController(text: '1.1');
  final _previewTagController = TextEditingController(text: 'custom');
  bool _glass = true;
  bool _rounded = true;
  String _template = 'glass';
  bool _isSaving = false;

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _idController,
      _nameController,
      _descriptionController,
      _authorController,
      _categoryController,
      _seedColorController,
      _accentColorController,
      _radiusController,
      _spacingController,
      _previewTagController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _applyTemplate(String template) {
    setState(() {
      _template = template;
      switch (template) {
        case 'glass':
          _seedColorController.text = '#7c3aed';
          _accentColorController.text = '#22d3ee';
          _radiusController.text = '24';
          _spacingController.text = '1.2';
          _glass = true;
          _rounded = true;
          _previewTagController.text = 'glass';
          break;
        case 'mint':
          _seedColorController.text = '#34d399';
          _accentColorController.text = '#0f172a';
          _radiusController.text = '16';
          _spacingController.text = '1.0';
          _glass = false;
          _rounded = true;
          _previewTagController.text = 'mint';
          break;
        case 'sunset':
          _seedColorController.text = '#f97316';
          _accentColorController.text = '#fb923c';
          _radiusController.text = '20';
          _spacingController.text = '1.1';
          _glass = true;
          _rounded = true;
          _previewTagController.text = 'sunset';
          break;
      }
    });
  }

  Future<void> _saveLocally() async {
    setState(() => _isSaving = true);
    try {
      final plugin = PluginDefinition(
        id: _idController.text.trim().replaceAll(RegExp(r'\s+'), '_'),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        author: _authorController.text.trim(),
        category: _categoryController.text.trim().isNotEmpty ? _categoryController.text.trim() : 'ui',
        seedColorHex: _seedColorController.text.trim(),
        accentColorHex: _accentColorController.text.trim(),
        cardRadius: int.tryParse(_radiusController.text.trim()) ?? 18,
        spacingMultiplier: double.tryParse(_spacingController.text.trim()) ?? 1.0,
        useGlassMorphism: _glass,
        useRoundedCorners: _rounded,
        previewTag: _previewTagController.text.trim(),
        sourceCode: '',
      );
      await PluginManager.addOrUpdatePlugin(plugin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${plugin.name} saved locally')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save plugin: $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _publishToFirebase() async {
    setState(() => _isSaving = true);
    try {
      final plugin = PluginDefinition(
        id: _idController.text.trim().replaceAll(RegExp(r'\s+'), '_'),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        author: _authorController.text.trim(),
        category: _categoryController.text.trim().isNotEmpty ? _categoryController.text.trim() : 'ui',
        seedColorHex: _seedColorController.text.trim(),
        accentColorHex: _accentColorController.text.trim(),
        cardRadius: int.tryParse(_radiusController.text.trim()) ?? 18,
        spacingMultiplier: double.tryParse(_spacingController.text.trim()) ?? 1.0,
        useGlassMorphism: _glass,
        useRoundedCorners: _rounded,
        previewTag: _previewTagController.text.trim(),
        sourceCode: '',
      );
      await PluginManager.addOrUpdatePlugin(plugin);
      await PluginManager.publishPluginToFirebase(plugin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${plugin.name} published to Firebase')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publish failed: $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plugin Editor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Build a plugin with a template', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _template,
              decoration: const InputDecoration(labelText: 'Template'),
              items: const [
                DropdownMenuItem(value: 'glass', child: Text('Glass')),
                DropdownMenuItem(value: 'mint', child: Text('Mint')),
                DropdownMenuItem(value: 'sunset', child: Text('Sunset')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _applyTemplate(value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(controller: _idController, decoration: const InputDecoration(labelText: 'Plugin ID')),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Plugin Name')),
            TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description')),
            TextField(controller: _authorController, decoration: const InputDecoration(labelText: 'Author')),
            TextField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Category')),
            TextField(controller: _seedColorController, decoration: const InputDecoration(labelText: 'Seed color (hex)')),
            TextField(controller: _accentColorController, decoration: const InputDecoration(labelText: 'Accent color (hex)')),
            TextField(controller: _radiusController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Card radius')),
            TextField(controller: _spacingController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Spacing multiplier')),
            TextField(controller: _previewTagController, decoration: const InputDecoration(labelText: 'Preview tag')),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Glass morphism'),
              value: _glass,
              onChanged: (value) => setState(() => _glass = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Rounded corners'),
              value: _rounded,
              onChanged: (value) => setState(() => _rounded = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveLocally,
                    icon: const Icon(Icons.save),
                    label: const Text('Save locally'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _isSaving ? null : _publishToFirebase,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Publish'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PluginStudioHomeScreen extends StatelessWidget {
  const PluginStudioHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plugin Studio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Plugin guide'),
              subtitle: const Text('See the .dart syntax and build conventions'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PluginGuideScreen())),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront),
              title: const Text('Plugin store'),
              subtitle: const Text('Browse local and Firebase-published plugins'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PluginStoreScreen())),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('In-app editor'),
              subtitle: const Text('Create a plugin from a template and save or publish it'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PluginEditorScreen())),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_open),
              title: const Text('Import .dart plugin'),
              subtitle: const Text('Pick a .dart file containing a PluginDefinition and bring it into the app'),
              onTap: () async {
                try {
                  await PluginManager.importPluginFromFile();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plugin imported successfully')));
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to import plugin: $error')));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
