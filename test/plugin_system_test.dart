import 'package:flutter_test/flutter_test.dart';
import 'package:chat/plugin_system.dart';

void main() {
  group('PluginDefinition parsing', () {
    test('parses a simple Dart plugin definition from source text', () {
      const source = r'''
import 'package:chat/plugin_system.dart';

final plugin = PluginDefinition(
  id: 'neon_glow',
  name: 'Neon Glow',
  description: 'Bright glassy UI',
  author: 'You',
  category: 'ui',
  seedColorHex: '#ff6b6b',
  accentColorHex: '#00f5d4',
  cardRadius: 24,
  spacingMultiplier: 1.2,
  useGlassMorphism: true,
  useRoundedCorners: true,
  previewTag: 'neon',
);
''';

      final plugin = PluginManager.parsePluginDefinitionFromDartSource(source);

      expect(plugin, isNotNull);
      expect(plugin!.id, 'neon_glow');
      expect(plugin.name, 'Neon Glow');
      expect(plugin.seedColorHex, '#ff6b6b');
      expect(plugin.useGlassMorphism, isTrue);
      expect(plugin.cardRadius, 24);
    });

    test('round-trips plugin definition to JSON and back', () {
      final plugin = PluginDefinition(
        id: 'mint_mode',
        name: 'Mint Mode',
        description: 'Fresh mint colors',
        author: 'Builder',
        category: 'ui',
        seedColorHex: '#4ade80',
        accentColorHex: '#0f172a',
        cardRadius: 16,
        spacingMultiplier: 1.0,
        useGlassMorphism: false,
        useRoundedCorners: true,
        previewTag: 'mint',
        isBuiltIn: false,
      );

      final json = plugin.toJson();
      final restored = PluginDefinition.fromJson(json);

      expect(restored.id, plugin.id);
      expect(restored.name, plugin.name);
      expect(restored.cardRadius, plugin.cardRadius);
    });
  });
}
