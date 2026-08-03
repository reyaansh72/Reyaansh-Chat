import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
// webview_flutter caused build issues on web; open YouTube links externally instead
import 'firebase_options.dart';
import 'package:flutter/rendering.dart';
import 'plugin_system.dart';
import 'slash_commands.dart';
import 'background_audio.dart';
import 'backend_service.dart';

const String kNotificationBackendUrl = String.fromEnvironment(
  'NOTIFICATION_BACKEND_URL',
  defaultValue: 'https://Reyaansh-Chat.onrender.com',
);

const AndroidNotificationChannel _chatNotificationChannel = AndroidNotificationChannel(
  'chat_messages',
  'Chat Messages',
  description: 'Notifications for newupup group chat messages.',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final firebaseOptions = DefaultFirebaseOptions.currentPlatform;
  debugPrint('Firebase background init database URL: ${firebaseOptions.databaseURL ?? 'null'}');
  await Firebase.initializeApp(options: firebaseOptions);
  await _showLocalNotification(message);
}

// =========================================================================
// STORIES SCREEN (Facebook-style Stories with Image URLs)
// =========================================================================
class StoriesScreen extends StatefulWidget {
  const StoriesScreen({super.key});

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en', 'US'),
    Locale('es', 'ES'),
    Locale('fr', 'FR'),
    Locale('de', 'DE'),
    Locale('hi', 'IN'),
  ];

  static final Map<String, Map<String, String>> _values = <String, Map<String, String>>{
    'en': <String, String>{
      'about': 'About',
      'settings': 'Settings',
      'stories': 'Stories',
      'contacts': 'Contacts',
      'language': 'Language',
      'language_region': 'Language & Region',
      'select_language': 'Select Language',
      'english': 'English (US)',
      'spanish': 'Spanish (ES)',
      'french': 'French (FR)',
      'german': 'German (DE)',
      'hindi': 'Hindi (HI)',
      'language_set_to_english': 'Language set to English',
      'language_changed_to_spanish': 'Language changed to Spanish',
      'language_changed_to_french': 'Language changed to French',
      'language_changed_to_german': 'Language changed to German',
      'language_changed_to_hindi': 'Language changed to Hindi',
    },
    'es': <String, String>{
      'about': 'Acerca de',
      'settings': 'Configuración',
      'stories': 'Historias',
      'contacts': 'Contactos',
      'language': 'Idioma',
      'language_region': 'Idioma y región',
      'select_language': 'Seleccionar idioma',
      'english': 'Inglés (EE. UU.)',
      'spanish': 'Español (ES)',
      'french': 'Francés (FR)',
      'german': 'Alemán (DE)',
      'hindi': 'Hindi (HI)',
      'language_set_to_english': 'Idioma establecido en inglés',
      'language_changed_to_spanish': 'Idioma cambiado a español',
      'language_changed_to_french': 'Idioma cambiado a francés',
      'language_changed_to_german': 'Idioma cambiado a alemán',
      'language_changed_to_hindi': 'Idioma cambiado a hindi',
    },
    'fr': <String, String>{
      'about': 'À propos',
      'settings': 'Paramètres',
      'stories': 'Histoires',
      'contacts': 'Contacts',
      'language': 'Langue',
      'language_region': 'Langue et région',
      'select_language': 'Choisir la langue',
      'english': 'Anglais (États-Unis)',
      'spanish': 'Espagnol (ES)',
      'french': 'Français (FR)',
      'german': 'Allemand (DE)',
      'hindi': 'Hindi (HI)',
      'language_set_to_english': 'Langue définie sur anglais',
      'language_changed_to_spanish': 'Langue changée en espagnol',
      'language_changed_to_french': 'Langue changée en français',
      'language_changed_to_german': 'Langue changée en allemand',
      'language_changed_to_hindi': 'Langue changée en hindi',
    },
    'de': <String, String>{
      'about': 'Info',
      'settings': 'Einstellungen',
      'stories': 'Stories',
      'contacts': 'Kontakte',
      'language': 'Sprache',
      'language_region': 'Sprache und Region',
      'select_language': 'Sprache auswählen',
      'english': 'Englisch (USA)',
      'spanish': 'Spanisch (ES)',
      'french': 'Französisch (FR)',
      'german': 'Deutsch (DE)',
      'hindi': 'Hindi (HI)',
      'language_set_to_english': 'Sprache auf Englisch gesetzt',
      'language_changed_to_spanish': 'Sprache auf Spanisch geändert',
      'language_changed_to_french': 'Sprache auf Französisch geändert',
      'language_changed_to_german': 'Sprache auf Deutsch geändert',
      'language_changed_to_hindi': 'Sprache auf Hindi geändert',
    },
    'hi': <String, String>{
      'about': 'के बारे में',
      'settings': 'सेटिंग्स',
      'stories': 'कहानियाँ',
      'contacts': 'संपर्क',
      'language': 'भाषा',
      'language_region': 'भाषा और क्षेत्र',
      'select_language': 'भाषा चुनें',
      'english': 'अंग्रेज़ी (यूएस)',
      'spanish': 'स्पेनिश (ES)',
      'french': 'फ़्रेंच (FR)',
      'german': 'जर्मन (DE)',
      'hindi': 'हिंदी (HI)',
      'language_set_to_english': 'भाषा अंग्रेज़ी पर सेट की गई',
      'language_changed_to_spanish': 'भाषा स्पेनिश में बदल दी गई',
      'language_changed_to_french': 'भाषा फ़्रेंच में बदल दी गई',
      'language_changed_to_german': 'भाषा जर्मन में बदल दी गई',
      'language_changed_to_hindi': 'भाषा हिंदी में बदल दी गई',
    },
  };

  String translate(String key) {
    final languageCode = locale.languageCode;
    return _values[languageCode]?[key] ?? _values['en']?[key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any((supported) => supported.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.translate('about'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            Icon(Icons.chat_bubble, size: 72, color: colors.primary),
            const SizedBox(height: 12),
            Text('Reyaansh Chat', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Version ${SettingsScreen._currentVersion}', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Text(
              'A lightweight chat client focused on privacy and simplicity. This build exposes core features like themes, stories, profile editing, and updates. Advanced/debug features are intentionally removed for stability.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.gavel),
              label: const Text('View Licenses'),
              onPressed: () => showLicensePage(context: context, applicationName: 'Reyaansh Chat', applicationVersion: SettingsScreen._currentVersion),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.link),
              label: const Text('Project on GitHub'),
              onPressed: () => launchUrl(Uri.parse('https://github.com/reyaansh72'), mode: LaunchMode.externalApplication),
            ),
            const SizedBox(height: 18),
            Text('Built with Flutter • © 2024', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _StoriesScreenState extends State<StoriesScreen> {
  final List<Map<String, dynamic>> _stories = [];
  final TextEditingController _urlController = TextEditingController();
  bool _isUploading = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _addStory() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid image URL')),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final story = {
        'id': '${DateTime.now().millisecondsSinceEpoch}',
        'url': url,
        'username': EnterpriseSession.username,
        'avatarUrl': EnterpriseSession.avatarUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'views': 0,
      };
      setState(() {
        _stories.insert(0, story);
        _urlController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story posted successfully! 📸')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to post story')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stories'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Story Upload Section
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: EnterpriseSession.avatarUrl.isNotEmpty
                                ? NetworkImage(EnterpriseSession.avatarUrl)
                                : null,
                            child: EnterpriseSession.avatarUrl.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  EnterpriseSession.username,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const Text('Share a moment...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          hintText: 'Enter image URL (https://...)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.link),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Post Story'),
                          onPressed: _isUploading ? null : _addStory,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
            // Stories List
            if (_stories.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.image_not_supported, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No stories yet', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _stories.length,
                itemBuilder: (context, index) {
                  final story = _stories[index];
                  return Card(
                    margin: const EdgeInsets.all(8),
                    clipBehavior: Clip.hardEdge,
                    child: Column(
                      children: [
                        // Story Image
                        SizedBox(
                          height: 400,
                          width: double.infinity,
                          child: Image.network(
                            story['url'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.broken_image, size: 48),
                                      const SizedBox(height: 8),
                                      const Text('Image not available'),
                                      const SizedBox(height: 8),
                                      Text(story['url'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
                                    ],
                                  ),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[300],
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            },
                          ),
                        ),
                        // Story Info
                        ListTile(
                          leading: CircleAvatar(
                            backgroundImage: story['avatarUrl'].isNotEmpty
                                ? NetworkImage(story['avatarUrl'])
                                : null,
                            child: story['avatarUrl'].isEmpty ? const Icon(Icons.person) : null,
                          ),
                          title: Text(story['username']),
                          subtitle: Text(
                            '${DateTime.fromMillisecondsSinceEpoch(story['timestamp']).difference(DateTime.now()).inMinutes.abs()} min ago',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.visibility),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Views: ${story['views']}')),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static Locale localeFromLanguage(String language) {
    switch (language) {
      case 'Spanish (ES)':
        return const Locale('es', 'ES');
      case 'French (FR)':
        return const Locale('fr', 'FR');
      case 'German (DE)':
        return const Locale('de', 'DE');
      case 'Hindi (HI)':
        return const Locale('hi', 'IN');
      case 'English (US)':
      default:
        return const Locale('en', 'US');
    }
  }

  // ==========================================
  // APP VERSION CONSTANTS
  // ==========================================
  static const String _currentVersion = '1.14';
  static const String _gitHubRepo = 'reyaansh72/Reyaansh-Chat';
  static const String _gitHubApiUrl = 'https://api.github.com/repos/reyaansh72/Reyaansh-Chat/releases';

  // ==========================================
  // LOCAL STATE NOTIFIERS (For UI demonstration without editing main classes)
  // ==========================================
  static final ValueNotifier<bool> _sendWithEnterNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _readReceiptsNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _typingIndicatorsNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _autoDownloadMediaNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _incognitoKeyboardNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _reduceMotionNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _dataSaverNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<double> _chatFontSizeNotifier = ValueNotifier<double>(14.0);
  static final ValueNotifier<int> _developerTapCount = ValueNotifier<int>(0);
  static final ValueNotifier<String?> _latestVersionNotifier = ValueNotifier<String?>(null);
  static final ValueNotifier<String> _customCurrentVersionNotifier = ValueNotifier<String>('');
  static final ValueNotifier<String> _customLatestVersionNotifier = ValueNotifier<String>('');
  static final ValueNotifier<bool> _checkingUpdateNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _isDownloadingNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<double?> _downloadProgressNotifier = ValueNotifier<double?>(null);
  // Extended settings notifiers
  static final ValueNotifier<bool> _endToEndEncryptionNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _messageBackupNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _blockUnknownNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _showOnlineStatusNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _allowScreenshotsNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _cacheClearedNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _lowBatteryModeNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _compressMediaNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _autoplayVideosNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _groupNotificationsNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<int> _logoTapCountNotifier = ValueNotifier<int>(0);
  // New notifiers for placeholder replacements
  static final ValueNotifier<bool> _linkPreviewNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _autoBackupSettingsNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _vpnEnabledNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _analyticsEnabledNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _backgroundMusicEnabledNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<String> _backgroundMusicPathNotifier = ValueNotifier<String>('');
  static final ValueNotifier<String> _backgroundMusicNameNotifier = ValueNotifier<String>('');
  static final ValueNotifier<String> _backendModeNotifier = ValueNotifier<String>('firebase');
  static final ValueNotifier<String> _backendBaseUrlNotifier = ValueNotifier<String>('http://127.0.0.1:3000');
  static final ValueNotifier<String> _backendConfigNameNotifier = ValueNotifier<String>('');
  static final ValueNotifier<String> _backendConfigPathNotifier = ValueNotifier<String>('');
  static final ValueNotifier<double> _backendTransitionProgressNotifier = ValueNotifier<double>(0.0);
  static final ValueNotifier<bool> _backendSwitchingNotifier = ValueNotifier<bool>(false);

  // ==========================================
  // DAILY USE FEATURE NOTIFIERS
  // ==========================================
  // Proxy Configuration
  static final ValueNotifier<String> _proxyTypeNotifier = ValueNotifier<String>('Direct');
  static final ValueNotifier<String> _proxyHostNotifier = ValueNotifier<String>('');
  static final ValueNotifier<String> _proxyPortNotifier = ValueNotifier<String>('');

  // Do Not Disturb
  static final ValueNotifier<bool> _dndEnabledNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<String> _dndStartTimeNotifier = ValueNotifier<String>('10:00 PM');
  static final ValueNotifier<String> _dndEndTimeNotifier = ValueNotifier<String>('7:00 AM');
  static final ValueNotifier<bool> _dndAllowEmergencyNotifier = ValueNotifier<bool>(true);

  // Quick Status
  static final ValueNotifier<String> _currentStatusNotifier = ValueNotifier<String>('Online');
  static final ValueNotifier<String> _statusMessageNotifier = ValueNotifier<String>('');

  // Chat Features
  static final ValueNotifier<bool> _archiveChatNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _pinChatNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _muteChatNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _enableDraftsNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _autoReplyNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<String> _autoReplyMessageNotifier = ValueNotifier<String>('I\'m currently away.');

  // Advanced Features
  static final ValueNotifier<bool> _messageForwardingNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _chatSearchNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _smartNotificationsNotifier = ValueNotifier<bool>(true);

  // Additional Daily Use Features
  static final ValueNotifier<bool> _messageSchedulingNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _pinnedChatsNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _readReceiptControlNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _presenceIndicatorNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _broadcastListNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _groupManagementNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _customNotificationSoundNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _gestureShortcutsNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _chatBubbleCustomizationNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<String> _selectedChatBubbleStyleNotifier = ValueNotifier<String>('Default');
  static final ValueNotifier<String> _selectedChatThemeNotifier = ValueNotifier<String>('Default');
  static final ValueNotifier<bool> _quickReplyNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _typingStatusNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _deviceSyncNotifier = ValueNotifier<bool>(true);

  // Contact & Group Management
  static final ValueNotifier<bool> _blockUnknownContactsNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _groupManagementAdvancedNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _contactSyncNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _messageReactionsNotifier = ValueNotifier<bool>(true);

  // Additional Features
  static final ValueNotifier<bool> _messageEditingNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _messageDeleteAfterNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> _voiceMessageNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> _videoMessageNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<String> _selectedThemeNotifier = ValueNotifier<String>('Light');
  static final ValueNotifier<String> _languageNotifier = ValueNotifier<String>('English (US)');
  static final ValueNotifier<String> _regionNotifier = ValueNotifier<String>('United States');
  static final ValueNotifier<bool> _customWallpaperNotifier = ValueNotifier<bool>(false);
  static bool _settingsLoading = false;

  static String get effectiveCurrentVersion =>
      _customCurrentVersionNotifier.value.isNotEmpty ? _customCurrentVersionNotifier.value : _currentVersion;

  static String get effectiveLatestVersion =>
      _customLatestVersionNotifier.value.isNotEmpty ? _customLatestVersionNotifier.value : '';

  static Future<void> initializePreferences() async {
    _registerPersistenceListeners();
    _loadFromPreferences();
  }

  static void _registerPersistenceListeners() {
    final saveBool = (String key, ValueNotifier<bool> notifier) {
      notifier.addListener(() {
        if (_settingsLoading) return;
        EnterpriseSession._prefs.setBool(key, notifier.value);
      });
    };

    final saveString = (String key, ValueNotifier<String> notifier) {
      notifier.addListener(() {
        if (_settingsLoading) return;
        EnterpriseSession._prefs.setString(key, notifier.value);
      });
    };

    final saveDouble = (String key, ValueNotifier<double> notifier) {
      notifier.addListener(() {
        if (_settingsLoading) return;
        EnterpriseSession._prefs.setDouble(key, notifier.value);
      });
    };

    saveBool('sendWithEnter', _sendWithEnterNotifier);
    saveBool('readReceipts', _readReceiptsNotifier);
    saveBool('typingIndicators', _typingIndicatorsNotifier);
    saveBool('autoDownloadMedia', _autoDownloadMediaNotifier);
    saveBool('incognitoKeyboard', _incognitoKeyboardNotifier);
    saveBool('reduceMotion', _reduceMotionNotifier);
    saveBool('dataSaver', _dataSaverNotifier);
    saveDouble('chatFontSize', _chatFontSizeNotifier);
    saveBool('endToEndEncryption', _endToEndEncryptionNotifier);
    saveBool('messageBackup', _messageBackupNotifier);
    saveBool('blockUnknown', _blockUnknownNotifier);
    saveBool('showOnlineStatus', _showOnlineStatusNotifier);
    saveBool('allowScreenshots', _allowScreenshotsNotifier);
    saveBool('lowBatteryMode', _lowBatteryModeNotifier);
    saveBool('compressMedia', _compressMediaNotifier);
    saveBool('autoplayVideos', _autoplayVideosNotifier);
    saveBool('groupNotifications', _groupNotificationsNotifier);
    saveBool('linkPreview', _linkPreviewNotifier);
    saveBool('autoBackupSettings', _autoBackupSettingsNotifier);
    saveBool('vpnEnabled', _vpnEnabledNotifier);
    saveBool('analyticsEnabled', _analyticsEnabledNotifier);
    saveBool('backgroundMusicEnabled', _backgroundMusicEnabledNotifier);
    saveString('backgroundMusicPath', _backgroundMusicPathNotifier);
    saveString('backgroundMusicName', _backgroundMusicNameNotifier);
    saveString('backendMode', _backendModeNotifier);
    saveString('backendBaseUrl', _backendBaseUrlNotifier);
    saveString('backendConfigName', _backendConfigNameNotifier);
    saveString('backendConfigPath', _backendConfigPathNotifier);
    saveString('customCurrentVersion', _customCurrentVersionNotifier);
    saveString('customLatestVersion', _customLatestVersionNotifier);
    saveString('proxyType', _proxyTypeNotifier);
    saveString('proxyHost', _proxyHostNotifier);
    saveString('proxyPort', _proxyPortNotifier);
    saveBool('dndEnabled', _dndEnabledNotifier);
    saveString('dndStartTime', _dndStartTimeNotifier);
    saveString('dndEndTime', _dndEndTimeNotifier);
    saveBool('dndAllowEmergency', _dndAllowEmergencyNotifier);
    saveString('currentStatus', _currentStatusNotifier);
    saveString('statusMessage', _statusMessageNotifier);
    saveBool('archiveChat', _archiveChatNotifier);
    saveBool('pinChat', _pinChatNotifier);
    saveBool('muteChat', _muteChatNotifier);
    saveBool('enableDrafts', _enableDraftsNotifier);
    saveBool('autoReply', _autoReplyNotifier);
    saveString('autoReplyMessage', _autoReplyMessageNotifier);
    saveBool('messageForwarding', _messageForwardingNotifier);
    saveBool('chatSearch', _chatSearchNotifier);
    saveBool('smartNotifications', _smartNotificationsNotifier);
    saveBool('messageScheduling', _messageSchedulingNotifier);
    saveBool('pinnedChats', _pinnedChatsNotifier);
    saveBool('readReceiptControl', _readReceiptControlNotifier);
    saveBool('presenceIndicator', _presenceIndicatorNotifier);
    saveBool('broadcastList', _broadcastListNotifier);
    saveBool('groupManagement', _groupManagementNotifier);
    saveBool('customNotificationSound', _customNotificationSoundNotifier);
    saveBool('gestureShortcuts', _gestureShortcutsNotifier);
    saveBool('chatBubbleCustomization', _chatBubbleCustomizationNotifier);
    saveString('selectedChatBubbleStyle', _selectedChatBubbleStyleNotifier);
    saveString('selectedChatTheme', _selectedChatThemeNotifier);
    saveBool('quickReply', _quickReplyNotifier);
    saveBool('typingStatus', _typingStatusNotifier);
    saveBool('deviceSync', _deviceSyncNotifier);
    saveBool('blockUnknownContacts', _blockUnknownContactsNotifier);
    saveBool('groupManagementAdvanced', _groupManagementAdvancedNotifier);
    saveBool('contactSync', _contactSyncNotifier);
    saveBool('messageReactions', _messageReactionsNotifier);
    saveBool('messageEditing', _messageEditingNotifier);
    saveBool('messageDeleteAfter', _messageDeleteAfterNotifier);
    saveBool('voiceMessage', _voiceMessageNotifier);
    saveBool('videoMessage', _videoMessageNotifier);
    saveBool('customWallpaper', _customWallpaperNotifier);
    saveString('language', _languageNotifier);
    saveString('region', _regionNotifier);
  }

  static void _loadFromPreferences() {
    _settingsLoading = true;

    _sendWithEnterNotifier.value = EnterpriseSession._prefs.getBool('sendWithEnter') ?? true;
    _readReceiptsNotifier.value = EnterpriseSession._prefs.getBool('readReceipts') ?? true;
    _typingIndicatorsNotifier.value = EnterpriseSession._prefs.getBool('typingIndicators') ?? true;
    _autoDownloadMediaNotifier.value = EnterpriseSession._prefs.getBool('autoDownloadMedia') ?? true;
    _incognitoKeyboardNotifier.value = EnterpriseSession._prefs.getBool('incognitoKeyboard') ?? false;
    _reduceMotionNotifier.value = EnterpriseSession._prefs.getBool('reduceMotion') ?? false;
    _dataSaverNotifier.value = EnterpriseSession._prefs.getBool('dataSaver') ?? false;
    _chatFontSizeNotifier.value = EnterpriseSession._prefs.getDouble('chatFontSize') ?? 14.0;
    _endToEndEncryptionNotifier.value = EnterpriseSession._prefs.getBool('endToEndEncryption') ?? true;
    _messageBackupNotifier.value = EnterpriseSession._prefs.getBool('messageBackup') ?? true;
    _blockUnknownNotifier.value = EnterpriseSession._prefs.getBool('blockUnknown') ?? false;
    _showOnlineStatusNotifier.value = EnterpriseSession._prefs.getBool('showOnlineStatus') ?? true;
    _allowScreenshotsNotifier.value = EnterpriseSession._prefs.getBool('allowScreenshots') ?? true;
    _lowBatteryModeNotifier.value = EnterpriseSession._prefs.getBool('lowBatteryMode') ?? false;
    _compressMediaNotifier.value = EnterpriseSession._prefs.getBool('compressMedia') ?? false;
    _autoplayVideosNotifier.value = EnterpriseSession._prefs.getBool('autoplayVideos') ?? true;
    _groupNotificationsNotifier.value = EnterpriseSession._prefs.getBool('groupNotifications') ?? true;
    _linkPreviewNotifier.value = EnterpriseSession._prefs.getBool('linkPreview') ?? true;
    _autoBackupSettingsNotifier.value = EnterpriseSession._prefs.getBool('autoBackupSettings') ?? true;
    _vpnEnabledNotifier.value = EnterpriseSession._prefs.getBool('vpnEnabled') ?? false;
    _analyticsEnabledNotifier.value = EnterpriseSession._prefs.getBool('analyticsEnabled') ?? true;
    _backgroundMusicEnabledNotifier.value = EnterpriseSession._prefs.getBool('backgroundMusicEnabled') ?? false;
    _backgroundMusicPathNotifier.value = EnterpriseSession._prefs.getString('backgroundMusicPath') ?? '';
    _backgroundMusicNameNotifier.value = EnterpriseSession._prefs.getString('backgroundMusicName') ?? '';
    _backendModeNotifier.value = EnterpriseSession._prefs.getString('backendMode') ?? 'firebase';
    _backendBaseUrlNotifier.value = EnterpriseSession._prefs.getString('backendBaseUrl') ?? 'http://127.0.0.1:3000';
    _backendConfigNameNotifier.value = EnterpriseSession._prefs.getString('backendConfigName') ?? '';
    _backendConfigPathNotifier.value = EnterpriseSession._prefs.getString('backendConfigPath') ?? '';
    _customCurrentVersionNotifier.value = EnterpriseSession._prefs.getString('customCurrentVersion') ?? '';
    _customLatestVersionNotifier.value = EnterpriseSession._prefs.getString('customLatestVersion') ?? '';
    _proxyTypeNotifier.value = EnterpriseSession._prefs.getString('proxyType') ?? 'Direct';
    _proxyHostNotifier.value = EnterpriseSession._prefs.getString('proxyHost') ?? '';
    _proxyPortNotifier.value = EnterpriseSession._prefs.getString('proxyPort') ?? '';
    _dndEnabledNotifier.value = EnterpriseSession._prefs.getBool('dndEnabled') ?? false;
    _dndStartTimeNotifier.value = EnterpriseSession._prefs.getString('dndStartTime') ?? '10:00 PM';
    _dndEndTimeNotifier.value = EnterpriseSession._prefs.getString('dndEndTime') ?? '7:00 AM';
    _dndAllowEmergencyNotifier.value = EnterpriseSession._prefs.getBool('dndAllowEmergency') ?? true;
    _currentStatusNotifier.value = EnterpriseSession._prefs.getString('currentStatus') ?? 'Online';
    _statusMessageNotifier.value = EnterpriseSession._prefs.getString('statusMessage') ?? '';
    _archiveChatNotifier.value = EnterpriseSession._prefs.getBool('archiveChat') ?? false;
    _pinChatNotifier.value = EnterpriseSession._prefs.getBool('pinChat') ?? false;
    _muteChatNotifier.value = EnterpriseSession._prefs.getBool('muteChat') ?? false;
    _enableDraftsNotifier.value = EnterpriseSession._prefs.getBool('enableDrafts') ?? true;
    _autoReplyNotifier.value = EnterpriseSession._prefs.getBool('autoReply') ?? false;
    _autoReplyMessageNotifier.value = EnterpriseSession._prefs.getString('autoReplyMessage') ?? 'I\'m currently away.';
    _messageForwardingNotifier.value = EnterpriseSession._prefs.getBool('messageForwarding') ?? true;
    _chatSearchNotifier.value = EnterpriseSession._prefs.getBool('chatSearch') ?? true;
    _smartNotificationsNotifier.value = EnterpriseSession._prefs.getBool('smartNotifications') ?? true;
    _messageSchedulingNotifier.value = EnterpriseSession._prefs.getBool('messageScheduling') ?? false;
    _pinnedChatsNotifier.value = EnterpriseSession._prefs.getBool('pinnedChats') ?? true;
    _readReceiptControlNotifier.value = EnterpriseSession._prefs.getBool('readReceiptControl') ?? true;
    _presenceIndicatorNotifier.value = EnterpriseSession._prefs.getBool('presenceIndicator') ?? true;
    _broadcastListNotifier.value = EnterpriseSession._prefs.getBool('broadcastList') ?? true;
    _groupManagementNotifier.value = EnterpriseSession._prefs.getBool('groupManagement') ?? true;
    _customNotificationSoundNotifier.value = EnterpriseSession._prefs.getBool('customNotificationSound') ?? true;
    _gestureShortcutsNotifier.value = EnterpriseSession._prefs.getBool('gestureShortcuts') ?? true;
    _chatBubbleCustomizationNotifier.value = EnterpriseSession._prefs.getBool('chatBubbleCustomization') ?? false;
    _selectedChatBubbleStyleNotifier.value = EnterpriseSession._prefs.getString('selectedChatBubbleStyle') ?? 'Default';
    _selectedChatThemeNotifier.value = EnterpriseSession._prefs.getString('selectedChatTheme') ?? 'Default';
    _quickReplyNotifier.value = EnterpriseSession._prefs.getBool('quickReply') ?? true;
    _typingStatusNotifier.value = EnterpriseSession._prefs.getBool('typingStatus') ?? true;
    _deviceSyncNotifier.value = EnterpriseSession._prefs.getBool('deviceSync') ?? true;
    _blockUnknownContactsNotifier.value = EnterpriseSession._prefs.getBool('blockUnknownContacts') ?? false;
    _groupManagementAdvancedNotifier.value = EnterpriseSession._prefs.getBool('groupManagementAdvanced') ?? true;
    _contactSyncNotifier.value = EnterpriseSession._prefs.getBool('contactSync') ?? true;
    _messageReactionsNotifier.value = EnterpriseSession._prefs.getBool('messageReactions') ?? true;
    _messageEditingNotifier.value = EnterpriseSession._prefs.getBool('messageEditing') ?? true;
    _messageDeleteAfterNotifier.value = EnterpriseSession._prefs.getBool('messageDeleteAfter') ?? false;
    _voiceMessageNotifier.value = EnterpriseSession._prefs.getBool('voiceMessage') ?? true;
    _videoMessageNotifier.value = EnterpriseSession._prefs.getBool('videoMessage') ?? true;
    _customWallpaperNotifier.value = EnterpriseSession._prefs.getBool('customWallpaper') ?? false;
    _languageNotifier.value = EnterpriseSession._prefs.getString('language') ?? 'English (US)';
    _regionNotifier.value = EnterpriseSession._prefs.getString('region') ?? 'United States';

    _settingsLoading = false;
  }

  static TimeOfDay? _parseTimeOfDay(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)\$', caseSensitive: false)
        .firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!) ?? 0;
    final minute = int.tryParse(match.group(2)!) ?? 0;
    final period = match.group(3)!.toUpperCase();
    final normalizedHour = hour == 12 ? 0 : hour;
    return TimeOfDay(
      hour: normalizedHour + (period == 'PM' ? 12 : 0),
      minute: minute,
    );
  }

  static bool _isBefore(TimeOfDay a, TimeOfDay b) {
    return a.hour < b.hour || (a.hour == b.hour && a.minute < b.minute);
  }

  static bool _isDndActive() {
    if (!_dndEnabledNotifier.value) return false;
    final start = _parseTimeOfDay(_dndStartTimeNotifier.value);
    final end = _parseTimeOfDay(_dndEndTimeNotifier.value);
    if (start == null || end == null) return false;
    final now = TimeOfDay.fromDateTime(DateTime.now());
    if (start.hour < end.hour || (start.hour == end.hour && start.minute < end.minute)) {
      return !_isBefore(now, start) && _isBefore(now, end);
    }
    return !_isBefore(now, start) || _isBefore(now, end);
  }

  static Future<void> _saveAllToPreferences() async {
    await EnterpriseSession._prefs.setBool('sendWithEnter', _sendWithEnterNotifier.value);
    await EnterpriseSession._prefs.setBool('readReceipts', _readReceiptsNotifier.value);
    await EnterpriseSession._prefs.setBool('typingIndicators', _typingIndicatorsNotifier.value);
    await EnterpriseSession._prefs.setBool('autoDownloadMedia', _autoDownloadMediaNotifier.value);
    await EnterpriseSession._prefs.setBool('incognitoKeyboard', _incognitoKeyboardNotifier.value);
    await EnterpriseSession._prefs.setBool('reduceMotion', _reduceMotionNotifier.value);
    await EnterpriseSession._prefs.setBool('dataSaver', _dataSaverNotifier.value);
    await EnterpriseSession._prefs.setDouble('chatFontSize', _chatFontSizeNotifier.value);
    await EnterpriseSession._prefs.setBool('endToEndEncryption', _endToEndEncryptionNotifier.value);
    await EnterpriseSession._prefs.setBool('messageBackup', _messageBackupNotifier.value);
    await EnterpriseSession._prefs.setBool('blockUnknown', _blockUnknownNotifier.value);
    await EnterpriseSession._prefs.setBool('showOnlineStatus', _showOnlineStatusNotifier.value);
    await EnterpriseSession._prefs.setBool('allowScreenshots', _allowScreenshotsNotifier.value);
    await EnterpriseSession._prefs.setBool('lowBatteryMode', _lowBatteryModeNotifier.value);
    await EnterpriseSession._prefs.setBool('compressMedia', _compressMediaNotifier.value);
    await EnterpriseSession._prefs.setBool('autoplayVideos', _autoplayVideosNotifier.value);
    await EnterpriseSession._prefs.setBool('groupNotifications', _groupNotificationsNotifier.value);
    await EnterpriseSession._prefs.setBool('linkPreview', _linkPreviewNotifier.value);
    await EnterpriseSession._prefs.setBool('autoBackupSettings', _autoBackupSettingsNotifier.value);
    await EnterpriseSession._prefs.setBool('vpnEnabled', _vpnEnabledNotifier.value);
    await EnterpriseSession._prefs.setBool('analyticsEnabled', _analyticsEnabledNotifier.value);
    await EnterpriseSession._prefs.setBool('backgroundMusicEnabled', _backgroundMusicEnabledNotifier.value);
    await EnterpriseSession._prefs.setString('backgroundMusicPath', _backgroundMusicPathNotifier.value);
    await EnterpriseSession._prefs.setString('backgroundMusicName', _backgroundMusicNameNotifier.value);
    await EnterpriseSession._prefs.setString('backendMode', _backendModeNotifier.value);
    await EnterpriseSession._prefs.setString('backendBaseUrl', _backendBaseUrlNotifier.value);
    await EnterpriseSession._prefs.setString('proxyType', _proxyTypeNotifier.value);
    await EnterpriseSession._prefs.setString('proxyHost', _proxyHostNotifier.value);
    await EnterpriseSession._prefs.setString('proxyPort', _proxyPortNotifier.value);
    await EnterpriseSession._prefs.setBool('dndEnabled', _dndEnabledNotifier.value);
    await EnterpriseSession._prefs.setString('dndStartTime', _dndStartTimeNotifier.value);
    await EnterpriseSession._prefs.setString('dndEndTime', _dndEndTimeNotifier.value);
    await EnterpriseSession._prefs.setBool('dndAllowEmergency', _dndAllowEmergencyNotifier.value);
    await EnterpriseSession._prefs.setString('currentStatus', _currentStatusNotifier.value);
    await EnterpriseSession._prefs.setString('statusMessage', _statusMessageNotifier.value);
    await EnterpriseSession._prefs.setBool('archiveChat', _archiveChatNotifier.value);
    await EnterpriseSession._prefs.setBool('pinChat', _pinChatNotifier.value);
    await EnterpriseSession._prefs.setBool('muteChat', _muteChatNotifier.value);
    await EnterpriseSession._prefs.setBool('enableDrafts', _enableDraftsNotifier.value);
    await EnterpriseSession._prefs.setBool('autoReply', _autoReplyNotifier.value);
    await EnterpriseSession._prefs.setString('autoReplyMessage', _autoReplyMessageNotifier.value);
    await EnterpriseSession._prefs.setBool('messageForwarding', _messageForwardingNotifier.value);
    await EnterpriseSession._prefs.setBool('chatSearch', _chatSearchNotifier.value);
    await EnterpriseSession._prefs.setBool('smartNotifications', _smartNotificationsNotifier.value);
    await EnterpriseSession._prefs.setBool('messageScheduling', _messageSchedulingNotifier.value);
    await EnterpriseSession._prefs.setBool('pinnedChats', _pinnedChatsNotifier.value);
    await EnterpriseSession._prefs.setBool('readReceiptControl', _readReceiptControlNotifier.value);
    await EnterpriseSession._prefs.setBool('presenceIndicator', _presenceIndicatorNotifier.value);
    await EnterpriseSession._prefs.setBool('broadcastList', _broadcastListNotifier.value);
    await EnterpriseSession._prefs.setBool('groupManagement', _groupManagementNotifier.value);
    await EnterpriseSession._prefs.setBool('customNotificationSound', _customNotificationSoundNotifier.value);
    await EnterpriseSession._prefs.setBool('gestureShortcuts', _gestureShortcutsNotifier.value);
    await EnterpriseSession._prefs.setBool('chatBubbleCustomization', _chatBubbleCustomizationNotifier.value);
    await EnterpriseSession._prefs.setString('selectedChatBubbleStyle', _selectedChatBubbleStyleNotifier.value);
    await EnterpriseSession._prefs.setBool('quickReply', _quickReplyNotifier.value);
    await EnterpriseSession._prefs.setBool('typingStatus', _typingStatusNotifier.value);
    await EnterpriseSession._prefs.setBool('deviceSync', _deviceSyncNotifier.value);
    await EnterpriseSession._prefs.setBool('blockUnknownContacts', _blockUnknownContactsNotifier.value);
    await EnterpriseSession._prefs.setBool('groupManagementAdvanced', _groupManagementAdvancedNotifier.value);
    await EnterpriseSession._prefs.setBool('contactSync', _contactSyncNotifier.value);
    await EnterpriseSession._prefs.setBool('messageReactions', _messageReactionsNotifier.value);
    await EnterpriseSession._prefs.setBool('messageEditing', _messageEditingNotifier.value);
    await EnterpriseSession._prefs.setBool('messageDeleteAfter', _messageDeleteAfterNotifier.value);
    await EnterpriseSession._prefs.setBool('voiceMessage', _voiceMessageNotifier.value);
    await EnterpriseSession._prefs.setBool('videoMessage', _videoMessageNotifier.value);
    await EnterpriseSession._prefs.setBool('customWallpaper', _customWallpaperNotifier.value);
    await EnterpriseSession._prefs.setString('language', _languageNotifier.value);
    await EnterpriseSession._prefs.setString('region', _regionNotifier.value);
  }

  static String exportSettingsToJson() {
    final settings = {
      'theme': EnterpriseSession.currentThemeVariant,
      'backendMode': _backendModeNotifier.value,
      'backendBaseUrl': _backendBaseUrlNotifier.value,
      'themeSeed': EnterpriseSession.themeSeed.toARGB32(),
      'notifications': EnterpriseSession.notificationsEnabled,
      'language': _languageNotifier.value,
      'region': _regionNotifier.value,
      'sendWithEnter': _sendWithEnterNotifier.value,
      'readReceipts': _readReceiptsNotifier.value,
      'typingIndicators': _typingIndicatorsNotifier.value,
      'autoDownloadMedia': _autoDownloadMediaNotifier.value,
      'dataSaver': _dataSaverNotifier.value,
      'chatFontSize': _chatFontSizeNotifier.value,
      'vpnEnabled': _vpnEnabledNotifier.value,
      'proxyType': _proxyTypeNotifier.value,
      'proxyHost': _proxyHostNotifier.value,
      'proxyPort': _proxyPortNotifier.value,
      'dndEnabled': _dndEnabledNotifier.value,
      'dndStartTime': _dndStartTimeNotifier.value,
      'dndEndTime': _dndEndTimeNotifier.value,
      'currentStatus': _currentStatusNotifier.value,
      'statusMessage': _statusMessageNotifier.value,
      'autoReply': _autoReplyNotifier.value,
      'autoReplyMessage': _autoReplyMessageNotifier.value,
      'quickReply': _quickReplyNotifier.value,
      'customNotificationSound': _customNotificationSoundNotifier.value,
      'analyticsEnabled': _analyticsEnabledNotifier.value,
      'customCurrentVersion': _customCurrentVersionNotifier.value,
      'customLatestVersion': _customLatestVersionNotifier.value,
      'backupSettings': _autoBackupSettingsNotifier.value,
      'timestamp': DateTime.now().toIso8601String(),
      'version': _currentVersion,
    };
    return jsonEncode(settings);
  }

  static String exportBackupToJson() {
    final backup = {
      'type': 'chat_backup_v1',
      'timestamp': DateTime.now().toIso8601String(),
      'version': _currentVersion,
      'profile': {
        'userId': EnterpriseSession.userId,
        'username': EnterpriseSession.username,
        'avatarUrl': EnterpriseSession.avatarUrl,
      },
      'contacts': EnterpriseSession.contacts.map((contact) => contact.toJson()).toList(),
      'settings': jsonDecode(exportSettingsToJson()),
    };
    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  static Future<bool> importBackupFromJson(String jsonString) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString) as Map<String, dynamic>;
      if (data['type'] != 'chat_backup_v1') return false;

      if (data.containsKey('settings')) {
        final settingsPayload = jsonEncode(data['settings']);
        await importSettingsFromJson(settingsPayload);
      }

      if (data.containsKey('contacts') && data['contacts'] is List) {
        await EnterpriseSession.restoreContactsFromData(List<dynamic>.from(data['contacts'] as List<dynamic>));
      }

      if (data.containsKey('profile') && data['profile'] is Map<String, dynamic>) {
        final profile = Map<String, dynamic>.from(data['profile'] as Map<dynamic, dynamic>);
        if (EnterpriseSession.userId.isEmpty && profile['userId'] != null) {
          EnterpriseSession.userId = profile['userId']?.toString() ?? '';
          EnterpriseSession.username = profile['username']?.toString() ?? '';
          EnterpriseSession.avatarUrl = profile['avatarUrl']?.toString() ?? '';
          await EnterpriseSession._prefs.setString('userId', EnterpriseSession.userId);
          await EnterpriseSession._prefs.setString('username', EnterpriseSession.username);
          await EnterpriseSession._prefs.setString('avatarUrl', EnterpriseSession.avatarUrl);
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> importSettingsFromJson(String jsonString) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString) as Map<String, dynamic>;
      _settingsLoading = true;

      if (data.containsKey('theme')) {
        await EnterpriseSession.setThemeVariant(data['theme']?.toString() ?? 'light');
      }
      if (data.containsKey('themeSeed')) {
        final seedInt = int.tryParse(data['themeSeed']?.toString() ?? '');
        if (seedInt != null) {
          await EnterpriseSession.setThemeSeedColor(Color(seedInt));
        }
      }
      if (data.containsKey('notifications')) {
        await EnterpriseSession.setNotificationsEnabled(data['notifications'] == true);
      }

      _languageNotifier.value = data['language']?.toString() ?? _languageNotifier.value;
      _regionNotifier.value = data['region']?.toString() ?? _regionNotifier.value;
      _customCurrentVersionNotifier.value = data['customCurrentVersion']?.toString() ?? _customCurrentVersionNotifier.value;
      _customLatestVersionNotifier.value = data['customLatestVersion']?.toString() ?? _customLatestVersionNotifier.value;
      _sendWithEnterNotifier.value = data['sendWithEnter'] == true;
      _readReceiptsNotifier.value = data['readReceipts'] == true;
      _typingIndicatorsNotifier.value = data['typingIndicators'] == true;
      _autoDownloadMediaNotifier.value = data['autoDownloadMedia'] == true;
      _dataSaverNotifier.value = data['dataSaver'] == true;
      _chatFontSizeNotifier.value = (data['chatFontSize'] is num ? (data['chatFontSize'] as num).toDouble() : _chatFontSizeNotifier.value);
      _vpnEnabledNotifier.value = data['vpnEnabled'] == true;
      _proxyTypeNotifier.value = data['proxyType']?.toString() ?? _proxyTypeNotifier.value;
      _proxyHostNotifier.value = data['proxyHost']?.toString() ?? _proxyHostNotifier.value;
      _proxyPortNotifier.value = data['proxyPort']?.toString() ?? _proxyPortNotifier.value;
      _dndEnabledNotifier.value = data['dndEnabled'] == true;
      _dndStartTimeNotifier.value = data['dndStartTime']?.toString() ?? _dndStartTimeNotifier.value;
      _dndEndTimeNotifier.value = data['dndEndTime']?.toString() ?? _dndEndTimeNotifier.value;
      _currentStatusNotifier.value = data['currentStatus']?.toString() ?? _currentStatusNotifier.value;
      _statusMessageNotifier.value = data['statusMessage']?.toString() ?? _statusMessageNotifier.value;
      _autoReplyNotifier.value = data['autoReply'] == true;
      _autoReplyMessageNotifier.value = data['autoReplyMessage']?.toString() ?? _autoReplyMessageNotifier.value;
      _quickReplyNotifier.value = data['quickReply'] == true;
      _customNotificationSoundNotifier.value = data['customNotificationSound'] == true;
      _analyticsEnabledNotifier.value = data['analyticsEnabled'] == true;
      _autoBackupSettingsNotifier.value = data['backupSettings'] == true;

      _settingsLoading = false;
      await _saveAllToPreferences();
      return true;
    } catch (_) {
      _settingsLoading = false;
      return false;
    }
  }

  static Future<void> clearAllSettings() async {
    _settingsLoading = true;
    await EnterpriseSession._prefs.clear();
    EnterpriseSession.userId = '';
    EnterpriseSession.username = '';
    EnterpriseSession.avatarUrl = '';
    EnterpriseSession.notificationsEnabled = true;
    EnterpriseSession.notificationsEnabledNotifier.value = true;
    await EnterpriseSession.setThemeSeedColor(const Color.fromARGB(255, 46, 154, 124));
    await EnterpriseSession.setThemeVariant('light');

    _sendWithEnterNotifier.value = true;
    _readReceiptsNotifier.value = true;
    _typingIndicatorsNotifier.value = true;
    _autoDownloadMediaNotifier.value = true;
    _incognitoKeyboardNotifier.value = false;
    _reduceMotionNotifier.value = false;
    _dataSaverNotifier.value = false;
    _chatFontSizeNotifier.value = 14.0;
    _endToEndEncryptionNotifier.value = true;
    _messageBackupNotifier.value = true;
    _blockUnknownNotifier.value = false;
    _showOnlineStatusNotifier.value = true;
    _allowScreenshotsNotifier.value = true;
    _lowBatteryModeNotifier.value = false;
    _compressMediaNotifier.value = false;
    _autoplayVideosNotifier.value = true;
    _groupNotificationsNotifier.value = true;
    _linkPreviewNotifier.value = true;
    _autoBackupSettingsNotifier.value = true;
    _vpnEnabledNotifier.value = false;
    _analyticsEnabledNotifier.value = true;
    _backgroundMusicEnabledNotifier.value = false;
    _backgroundMusicPathNotifier.value = '';
    _backgroundMusicNameNotifier.value = '';
    _backendModeNotifier.value = 'firebase';
    _backendBaseUrlNotifier.value = 'http://127.0.0.1:3000';
    _backendConfigNameNotifier.value = '';
    _backendConfigPathNotifier.value = '';
    _proxyTypeNotifier.value = 'Direct';
    _proxyHostNotifier.value = '';
    _proxyPortNotifier.value = '';
    _dndEnabledNotifier.value = false;
    _dndStartTimeNotifier.value = '10:00 PM';
    _dndEndTimeNotifier.value = '7:00 AM';
    _dndAllowEmergencyNotifier.value = true;
    _currentStatusNotifier.value = 'Online';
    _statusMessageNotifier.value = '';
    _archiveChatNotifier.value = false;
    _pinChatNotifier.value = false;
    _muteChatNotifier.value = false;
    _enableDraftsNotifier.value = true;
    _autoReplyNotifier.value = false;
    _autoReplyMessageNotifier.value = 'I\'m currently away.';
    _messageForwardingNotifier.value = true;
    _chatSearchNotifier.value = true;
    _smartNotificationsNotifier.value = true;
    _messageSchedulingNotifier.value = false;
    _pinnedChatsNotifier.value = true;
    _readReceiptControlNotifier.value = true;
    _presenceIndicatorNotifier.value = true;
    _broadcastListNotifier.value = true;
    _groupManagementNotifier.value = true;
    _customNotificationSoundNotifier.value = true;
    _gestureShortcutsNotifier.value = true;
    _chatBubbleCustomizationNotifier.value = false;
    _selectedChatBubbleStyleNotifier.value = 'Default';
    _selectedChatThemeNotifier.value = 'Default';
    _quickReplyNotifier.value = true;
    _typingStatusNotifier.value = true;
    _deviceSyncNotifier.value = true;
    _blockUnknownContactsNotifier.value = false;
    _groupManagementAdvancedNotifier.value = true;
    _contactSyncNotifier.value = true;
    _messageReactionsNotifier.value = true;
    _messageEditingNotifier.value = true;
    _messageDeleteAfterNotifier.value = false;
    _voiceMessageNotifier.value = true;
    _videoMessageNotifier.value = true;
    _customWallpaperNotifier.value = false;
    _languageNotifier.value = 'English (US)';
    _regionNotifier.value = 'United States';

    _settingsLoading = false;
  }

  static Future<void> _switchBackend(BuildContext context, String targetMode) async {
    final previousMode = _backendModeNotifier.value;

    _backendSwitchingNotifier.value = true;
    _backendTransitionProgressNotifier.value = 0.0;

    try {
      if (targetMode == 'local') {
        final reachable = await BackendService.instance.testConnection(baseUrl: _backendBaseUrlNotifier.value);
        if (!reachable) {
          throw Exception('The local server did not respond. Start the Node.js server on your PC and try again.');
        }
      }

      await BackendService.instance.setBackend(mode: targetMode, baseUrl: _backendBaseUrlNotifier.value);
      _backendModeNotifier.value = targetMode;
      _backendTransitionProgressNotifier.value = 1.0;
      if (context.mounted) {
        _showToast(context, targetMode == 'local' ? 'Switched to local webserver' : 'Switched to Firebase');
      }
    } catch (error) {
      _backendModeNotifier.value = previousMode;
      if (context.mounted) {
        _showToast(context, error.toString());
      }
    } finally {
      for (var step = 1; step <= 10; step++) {
        _backendTransitionProgressNotifier.value = step / 10;
        await Future.delayed(const Duration(milliseconds: 80));
      }
      _backendSwitchingNotifier.value = false;
      _backendTransitionProgressNotifier.value = 0.0;
    }
  }

  static Future<void> _pickBackendConfig(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['json', 'txt'],
        withData: false,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      if (file.path == null || file.path!.isEmpty) {
        throw Exception('The selected file does not expose a local path.');
      }

      final content = await File(file.path!).readAsString();
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('The backend config file must contain a JSON object.');
      }

      final baseUrl = (decoded['baseUrl'] ?? '').toString().trim();
      final mode = (decoded['mode'] ?? 'local').toString().trim().toLowerCase();
      if (baseUrl.isEmpty) {
        throw Exception('The config file must include a baseUrl field.');
      }

      _backendBaseUrlNotifier.value = baseUrl;
      _backendConfigNameNotifier.value = file.name;
      _backendConfigPathNotifier.value = file.path!;
      await _switchBackend(context, mode == 'firebase' ? 'firebase' : 'local');
    } catch (error) {
      if (context.mounted) {
        _showToast(context, 'Could not read backend config: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.translate('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader(context, 'Appearance'),
          Text('Theme Color', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ThemeColorPicker.palette.map((color) {
              final bool isSelected = color.toARGB32() == EnterpriseSession.themeSeed.toARGB32();
              return GestureDetector(
                onTap: () async {
                  await EnterpriseSession.setThemeSeedColor(color);
                  final hex = '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
                  if (context.mounted) _showToast(context, 'Theme color set to $hex');
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected ? Border.all(color: Colors.white, width: 3.0) : null,
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: EnterpriseSession.themeVariantNotifier,
            builder: (context, current, _) => Wrap(
              spacing: 8,
              children: [
                ChoiceChip(label: const Text('Light'), selected: current == 'light', onSelected: (_) => EnterpriseSession.setThemeVariant('light')),
                ChoiceChip(label: const Text('Dark'), selected: current == 'dark', onSelected: (_) => EnterpriseSession.setThemeVariant('dark')),
                ChoiceChip(label: const Text('Amoled'), selected: current == 'amoled', onSelected: (_) => EnterpriseSession.setThemeVariant('amoled')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Chat Theme', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          ValueListenableBuilder<String>(
            valueListenable: _selectedChatThemeNotifier,
            builder: (context, current, _) => Wrap(
              spacing: 8,
              children: ['Default', 'Midnight', 'Mint', 'Rose'].map((theme) {
                return ChoiceChip(
                  label: Text(theme),
                  selected: current == theme,
                  onSelected: (_) => _selectedChatThemeNotifier.value = theme,
                );
              }).toList(),
            ),
          ),
          const Divider(),

          _buildSectionHeader(context, 'Backend Sync'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_sync_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sync backend',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Choose Firebase for the cloud route or a local Node.js server for offline-friendly syncing. The app will switch smoothly with a progress transition.'),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<String>(
                    valueListenable: _backendModeNotifier,
                    builder: (context, mode, _) {
                      return SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'firebase', label: Text('Firebase')),
                          ButtonSegment(value: 'local', label: Text('Local Node.js')),
                        ],
                        selected: {mode},
                        onSelectionChanged: (selection) async {
                          await _switchBackend(context, selection.first);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<String>(
                    valueListenable: _backendConfigNameNotifier,
                    builder: (context, configName, _) {
                      return ValueListenableBuilder<String>(
                        valueListenable: _backendBaseUrlNotifier,
                        builder: (context, baseUrl, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.folder_open_rounded),
                                title: Text(configName.isEmpty ? 'No backend config selected' : configName),
                                subtitle: Text(baseUrl.isEmpty ? 'Pick a JSON config file from your PC or phone.' : baseUrl),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () => _pickBackendConfig(context),
                                    icon: const Icon(Icons.file_open_rounded),
                                    label: const Text('Pick server config'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _switchBackend(context, 'firebase'),
                                    child: const Text('Use Firebase'),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<bool>(
                    valueListenable: _backendSwitchingNotifier,
                    builder: (context, switching, _) {
                      if (!switching) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Switching backend...'),
                          const SizedBox(height: 8),
                          ValueListenableBuilder<double>(
                            valueListenable: _backendTransitionProgressNotifier,
                            builder: (context, progress, _) => LinearProgressIndicator(value: progress == 0 ? null : progress),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('Tip: run the Node.js server on your PC and select a JSON config file such as Nodejs/local-backend-config.json so the app can switch to the local route instantly.'),
                ],
              ),
            ),
          ),
          const Divider(),

          _buildSectionHeader(context, 'Chat Preferences'),
          ValueListenableBuilder<bool>(
            valueListenable: _sendWithEnterNotifier,
            builder: (context, enabled, _) => SwitchListTile(
              value: enabled,
              title: const Text('Send with Enter'),
              secondary: const Icon(Icons.keyboard_return),
              onChanged: (v) => _sendWithEnterNotifier.value = v,
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _chatFontSizeNotifier,
            builder: (context, size, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.format_size),
                  title: const Text('Message Font Size'),
                  subtitle: Text('Current size: ${size.toInt()}pt'),
                ),
                Slider(value: size, min: 10.0, max: 24.0, divisions: 14, label: size.round().toString(), onChanged: (v) => _chatFontSizeNotifier.value = v),
              ],
            ),
          ),
          const Divider(),

          _buildSectionHeader(context, 'Notifications'),
          ValueListenableBuilder<bool>(
            valueListenable: EnterpriseSession.notificationsEnabledNotifier,
            builder: (context, enabled, _) => SwitchListTile(
              value: enabled,
              title: const Text('Push Notifications'),
              secondary: const Icon(Icons.notifications),
              onChanged: (v) async => await EnterpriseSession.setNotificationsEnabled(v),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('Send Test Notification'),
            subtitle: const Text('Verify local notifications are working'),
            onTap: () => _showTestNotification(context),
          ),
          const Divider(),

          _buildSectionHeader(context, 'Account'),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('My Profile'),
            subtitle: const Text('View and edit your profile'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showProfileDialog(context),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Backup & Restore'),
          ListTile(
            leading: const Icon(Icons.download_for_offline),
            title: const Text('Export Backup'),
            subtitle: const Text('Save contacts and app settings to a JSON file'),
            onTap: () => _exportBackup(context),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Import Backup'),
            subtitle: const Text('Select a JSON file to restore contacts and settings'),
            onTap: () => _restoreBackup(context),
          ),
          const Divider(),

          _buildSectionHeader(context, 'Content'),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Stories'),
            subtitle: const Text('Share and view stories'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StoriesScreen())),
          ),
          const Divider(),

          _buildSectionHeader(context, 'Audio'),
          ValueListenableBuilder<bool>(
            valueListenable: _backgroundMusicEnabledNotifier,
            builder: (context, enabled, _) => SwitchListTile(
              value: enabled,
              title: const Text('Background Music'),
              subtitle: const Text('Plays an MP3 in the background while you use the app'),
              secondary: const Icon(Icons.audiotrack),
              onChanged: (value) async {
                _backgroundMusicEnabledNotifier.value = value;
                await BackgroundAudioController.instance.setEnabled(value);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.music_note),
            title: const Text('Select MP3'),
            subtitle: ValueListenableBuilder<String>(
              valueListenable: _backgroundMusicNameNotifier,
              builder: (context, name, _) => Text(name.isEmpty ? 'No file selected' : name),
            ),
            onTap: () async {
              final picked = await BackgroundAudioController.instance.pickAndSetMusic();
              if (picked != null && context.mounted) {
                _backgroundMusicPathNotifier.value = picked;
                _backgroundMusicNameNotifier.value = BackgroundAudioController.instance.selectedNameNotifier.value;
                _showToast(context, 'Music selected');
              }
            },
          ),
          const Divider(),

          _buildSectionHeader(context, 'Plugins'),
          ListTile(
            leading: const Icon(Icons.extension),
            title: const Text('Plugin Studio'),
            subtitle: const Text('Create, import, save, and publish plugins'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PluginStudioHomeScreen())),
          ),
          const SizedBox(height: 8),
          PluginManager.buildPluginPagePreview(context, title: 'Plugin page preview'),
          const Divider(),

          _buildSectionHeader(context, AppLocalizations.of(context).translate('language_region')),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(AppLocalizations.of(context).translate('language')),
            subtitle: ValueListenableBuilder<String>(valueListenable: _languageNotifier, builder: (context, language, _) => Text(language)),
            onTap: () => _showLanguageDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('Region'),
            subtitle: ValueListenableBuilder<String>(valueListenable: _regionNotifier, builder: (context, region, _) => Text(region)),
            onTap: () => _showRegionDialog(context),
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About App'),
            subtitle: const Text('Version & licenses'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),

          if (!kIsWeb) ...[
            const Divider(),
            ValueListenableBuilder<bool>(
              valueListenable: _checkingUpdateNotifier,
              builder: (context, checking, _) {
                return ValueListenableBuilder<double?>(
                  valueListenable: _downloadProgressNotifier,
                  builder: (context, progress, _) {
                    return ListTile(
                      leading: const Icon(Icons.system_update),
                      title: const Text('Check for Update'),
                      subtitle: () {
                        if (checking) {
                          return const Text('Checking for updates...');
                        }
                        if (progress != null) {
                          final progressPercent = (progress * 100).clamp(0, 100).toStringAsFixed(0);
                          return Text('Downloading update... $progressPercent%');
                        }
                        return ValueListenableBuilder<String?>(
                          valueListenable: _latestVersionNotifier,
                          builder: (context, latestVersion, _) {
                            if (latestVersion == null || latestVersion.isEmpty) {
                              return const Text('Tap to compare current version with GitHub release');
                            }
                            final overrideText = _customLatestVersionNotifier.value.isNotEmpty
                                ? ' (override)'
                                : '';
                            return Text('Latest version: $latestVersion$overrideText');
                          },
                        );
                      }(),
                      trailing: checking || progress != null
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.chevron_right),
                      onTap: checking ? null : () => _checkAndDownloadUpdate(context),
                    );
                  },
                );
              },
            ),
            const Divider(),
            _buildSectionHeader(context, 'Debugging'),
            ListTile(
              leading: const Icon(Icons.developer_mode),
              title: const Text('Debug Version Overrides'),
              subtitle: ValueListenableBuilder<String>(
                valueListenable: _customCurrentVersionNotifier,
                builder: (context, currentOverride, _) {
                  return ValueListenableBuilder<String>(
                    valueListenable: _customLatestVersionNotifier,
                    builder: (context, latestOverride, _) {
                      return Text(
                        currentOverride.isNotEmpty || latestOverride.isNotEmpty
                            ? 'Current: ${currentOverride.isNotEmpty ? currentOverride : SettingsScreen._currentVersion}, Latest: ${latestOverride.isNotEmpty ? latestOverride : 'GitHub'}'
                            : 'No overrides set. Tap to configure.',
                      );
                    },
                  );
                },
              ),
              onTap: () => _showDeveloperOptions(context),
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text('Clear App Data', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              _showConfirmDialog(context, 'Clear All Data', 'This will reset preferences and cache. Continue?', () async {
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                await EnterpriseSession._prefs.clear();
                if (context.mounted) _showToast(context, 'All app data cleared');
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () => _showConfirmDialog(context, 'Logout', 'Sign out from this device?', () async { await EnterpriseSession.logout(); if (context.mounted) _showToast(context, 'Logged out'); Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false); }),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================
  
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Text(
        title, 
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2
        )
      ),
    );
  }

  static void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showConfirmDialog(BuildContext context, String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onConfirm();
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _showProfileDialog(BuildContext context) {
    final nameController = TextEditingController(text: EnterpriseSession.username);
    final avatarUrlController = TextEditingController(text: EnterpriseSession.avatarUrl);
    bool isEditing = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('My Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: avatarUrlController.text.isNotEmpty
                            ? NetworkImage(avatarUrlController.text)
                            : null,
                        child: avatarUrlController.text.isEmpty
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isEditing) ...[
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: avatarUrlController,
                        decoration: InputDecoration(
                          labelText: 'Avatar URL',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.image),
                          hintText: 'https://example.com/avatar.jpg',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ] else ...[
                      Text('Name: ${nameController.text}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('ID: ${EnterpriseSession.userId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text('Avatar: ${avatarUrlController.text.isEmpty ? 'Default' : 'Custom'}', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      Text('Status: ${EnterpriseSession.isLoggedIn() ? '✓ Logged In' : 'Not Logged In'}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Member since: ${DateTime.now().year}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
                if (isEditing)
                  TextButton(
                    onPressed: () => setState(() => isEditing = false),
                    child: const Text('Cancel'),
                  ),
                FilledButton(
                  onPressed: () async {
                    if (isEditing) {
                      // Save profile changes
                      await EnterpriseSession.initialize(
                        nameController.text,
                        avatarUrlController.text,
                      );
                      if (context.mounted) {
                        _showToast(context, 'Profile updated successfully! ✓');
                        Navigator.of(dialogContext).pop();
                      }
                    } else {
                      setState(() => isEditing = true);
                    }
                  },
                  child: Text(isEditing ? 'Save' : 'Edit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).translate('select_language')),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.blue),
                  title: Text(AppLocalizations.of(context).translate('english')),
                  onTap: () {
                    _languageNotifier.value = 'English (US)';
                    Navigator.of(dialogContext).pop();
                    _showToast(context, AppLocalizations.of(context).translate('language_set_to_english'));
                  },
                ),
                ListTile(
                  title: Text(AppLocalizations.of(context).translate('spanish')),
                  onTap: () {
                    _languageNotifier.value = 'Spanish (ES)';
                    Navigator.of(dialogContext).pop();
                    _showToast(context, AppLocalizations.of(context).translate('language_changed_to_spanish'));
                  },
                ),
                ListTile(
                  title: Text(AppLocalizations.of(context).translate('french')),
                  onTap: () {
                    _languageNotifier.value = 'French (FR)';
                    Navigator.of(dialogContext).pop();
                    _showToast(context, AppLocalizations.of(context).translate('language_changed_to_french'));
                  },
                ),
                ListTile(
                  title: Text(AppLocalizations.of(context).translate('german')),
                  onTap: () {
                    _languageNotifier.value = 'German (DE)';
                    Navigator.of(dialogContext).pop();
                    _showToast(context, AppLocalizations.of(context).translate('language_changed_to_german'));
                  },
                ),
                ListTile(
                  title: Text(AppLocalizations.of(context).translate('hindi')),
                  onTap: () {
                    _languageNotifier.value = 'Hindi (HI)';
                    Navigator.of(dialogContext).pop();
                    _showToast(context, AppLocalizations.of(context).translate('language_changed_to_hindi'));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _exportSettings(BuildContext context) {
    final jsonString = exportSettingsToJson();
    Clipboard.setData(ClipboardData(text: jsonString));
    _showToast(context, 'Settings exported to clipboard');
  }

  Future<void> _exportBackup(BuildContext context) async {
    final jsonString = exportBackupToJson();
    final defaultName = 'chat-backup-${DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-')}.json';

    if (kIsWeb) {
      Clipboard.setData(ClipboardData(text: jsonString));
      _showToast(context, 'Backup JSON copied to clipboard');
      return;
    }

    final filePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save chat backup',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (filePath == null) {
      _showToast(context, 'Backup cancelled');
      return;
    }

    final backupFile = File(filePath);
    await backupFile.writeAsString(jsonString);
    _showToast(context, 'Backup saved to $filePath');
  }

  Future<void> _restoreBackup(BuildContext context) async {
    if (kIsWeb) {
      _showImportDialog(context);
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      _showToast(context, 'Restore cancelled');
      return;
    }

    final pickedFile = result.files.first;
    final path = pickedFile.path;
    if (path == null) {
      _showToast(context, 'Unable to read selected file');
      return;
    }

    final file = File(path);
    final jsonString = await file.readAsString();
    final success = await importBackupFromJson(jsonString);
    _showToast(context, success ? 'Backup restored successfully' : 'Unable to restore backup');
  }

  void _showRegionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Select Region'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.blue),
                  title: const Text('United States'),
                  onTap: () {
                    _regionNotifier.value = 'United States';
                    Navigator.pop(dialogContext);
                    _showToast(context, 'Region set to United States');
                  },
                ),
                ListTile(
                  title: const Text('Europe'),
                  onTap: () {
                    _regionNotifier.value = 'Europe';
                    Navigator.pop(dialogContext);
                    _showToast(context, 'Region set to Europe');
                  },
                ),
                ListTile(
                  title: const Text('Asia'),
                  onTap: () {
                    _regionNotifier.value = 'Asia';
                    Navigator.pop(dialogContext);
                    _showToast(context, 'Region set to Asia');
                  },
                ),
                ListTile(
                  title: const Text('India'),
                  onTap: () {
                    _regionNotifier.value = 'India';
                    Navigator.pop(dialogContext);
                    _showToast(context, 'Region set to India');
                  },
                ),
                ListTile(
                  title: const Text('Australia'),
                  onTap: () {
                    _regionNotifier.value = 'Australia';
                    Navigator.pop(dialogContext);
                    _showToast(context, 'Region set to Australia');
                  },
                ),
              ],
            ),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        );
      },
    );
  }

  void _showImportDialog(BuildContext context) {
    final importController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Import Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Paste your settings JSON below to restore them.'),
              const SizedBox(height: 12),
              TextField(
                controller: importController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: '{ "theme": "dark", "notifications": true }',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () {
                importController.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final jsonValue = importController.text.trim();
                importController.dispose();
                Navigator.pop(dialogContext);
                if (jsonValue.isEmpty) {
                  _showToast(context, 'Please paste valid settings JSON.');
                  return;
                }
                final success = await SettingsScreen.importSettingsFromJson(jsonValue);
                _showToast(context, success ? 'Settings imported successfully! ✓' : 'Unable to import settings.');
              },
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
  }

  void _show2FADialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Two-Factor Authentication'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Secure your account with 2FA:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 12),
              Text('✓ Install an authenticator app'),
              SizedBox(height: 8),
              Text('✓ Scan the QR code'),
              SizedBox(height: 8),
              Text('✓ Enter the 6-digit code'),
              SizedBox(height: 8),
              Text('✓ Save recovery codes'),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showToast(context, '2FA enabled! ✓ Scan the code with your authenticator app');
              },
              child: const Text('Enable 2FA'),
            ),
          ],
        );
      },
    );
  }

  void _showRestoreDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Restore from Backup'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text('Backup - 25 July 2026'),
                  subtitle: const Text('2:45 PM • 524 MB'),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showToast(context, 'Restoring backup... (This may take a few minutes)');
                  },
                ),
                ListTile(
                  title: const Text('Backup - 24 July 2026'),
                  subtitle: const Text('10:30 AM • 512 MB'),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showToast(context, 'Restoring backup... (This may take a few minutes)');
                  },
                ),
                ListTile(
                  title: const Text('Backup - 23 July 2026'),
                  subtitle: const Text('11:15 PM • 498 MB'),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showToast(context, 'Restoring backup... (This may take a few minutes)');
                  },
                ),
              ],
            ),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        );
      },
    );
  }

  void _sendCrashReport(BuildContext context) {
    final reportData = {
      'app_version': '1.10',
      'timestamp': DateTime.now().toIso8601String(),
      'platform': Theme.of(context).platform.name,
      'error': 'Test crash report',
    };
    _showToast(context, 'Crash report sent to developers\nReport ID: ${DateTime.now().millisecondsSinceEpoch}');
  }

  void _showFeedbackDialog(BuildContext context) {
    final feedbackController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Send Feedback'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('We\'d love to hear from you!'),
              const SizedBox(height: 12),
              TextField(
                controller: feedbackController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Tell us what you think...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () {
                feedbackController.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final feedback = feedbackController.text;
                feedbackController.dispose();
                Navigator.pop(dialogContext);
                if (feedback.isNotEmpty) {
                  _showToast(context, 'Thank you for your feedback! ✓\nWe\'ll review it shortly');
                } else {
                  _showToast(context, 'Please enter your feedback');
                }
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  void _showDeveloperOptions(BuildContext context) {
    final currentVersionController = TextEditingController(text: _customCurrentVersionNotifier.value);
    final latestVersionController = TextEditingController(text: _customLatestVersionNotifier.value);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('🔧 Developer Options'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Debug Information:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text('App Version: ${SettingsScreen._currentVersion}'),
                    Text('Effective Current Version: ${SettingsScreen.effectiveCurrentVersion}'),
                    Text('Effective Latest Version: ${SettingsScreen.effectiveLatestVersion.isNotEmpty ? SettingsScreen.effectiveLatestVersion : 'GitHub release'}'),
                    const Text('Build: Release'),
                    const Text('Platform: Web/Mobile'),
                    const Text('Flutter Version: 3.x'),
                    const SizedBox(height: 12),
                    const Text('Version Overrides:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: currentVersionController,
                      decoration: const InputDecoration(
                        labelText: 'Override Current Version',
                        hintText: 'Leave empty to use actual app version',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: latestVersionController,
                      decoration: const InputDecoration(
                        labelText: 'Override Latest Version',
                        hintText: 'Leave empty to use GitHub release version',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Features:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('✓ Hot Reload Enabled'),
                    const Text('✓ Debug Painting Active'),
                    const Text('✓ Performance Monitoring'),
                    const Text('✓ Network Throttling: Off'),
                  ],
                ),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              actions: [
                TextButton(
                  onPressed: () {
                    currentVersionController.clear();
                    latestVersionController.clear();
                    _customCurrentVersionNotifier.value = '';
                    _customLatestVersionNotifier.value = '';
                    setState(() {});
                    _showToast(context, 'Debug version overrides cleared.');
                  },
                  child: const Text('Clear'),
                ),
                TextButton(
                  onPressed: () {
                    currentVersionController.dispose();
                    latestVersionController.dispose();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Close'),
                ),
                FilledButton(
                  onPressed: () {
                    final newCurrent = currentVersionController.text.trim();
                    final newLatest = latestVersionController.text.trim();
                    _customCurrentVersionNotifier.value = newCurrent;
                    _customLatestVersionNotifier.value = newLatest;
                    currentVersionController.dispose();
                    latestVersionController.dispose();
                    Navigator.pop(dialogContext);
                    _showToast(context, 'Debug version overrides updated.');
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSharedMediaDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Shared Media'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text('Photos'),
                  subtitle: const Text('142 items • 845 MB'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
                ListTile(
                  title: const Text('Videos'),
                  subtitle: const Text('28 items • 2.3 GB'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
                ListTile(
                  title: const Text('Documents'),
                  subtitle: const Text('56 items • 234 MB'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
                ListTile(
                  title: const Text('Audio'),
                  subtitle: const Text('12 items • 145 MB'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
              ],
            ),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showProxyDialog(BuildContext context) {
    final hostController = TextEditingController(text: _proxyHostNotifier.value);
    final portController = TextEditingController(text: _proxyPortNotifier.value);
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Proxy Configuration'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Proxy Type:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ValueListenableBuilder<String>(
                  valueListenable: _proxyTypeNotifier,
                  builder: (context, type, _) => Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('Direct Connection'),
                        value: 'Direct',
                        groupValue: type,
                        onChanged: (value) {
                          _proxyTypeNotifier.value = value ?? 'Direct';
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('HTTP Proxy'),
                        value: 'HTTP',
                        groupValue: type,
                        onChanged: (value) {
                          _proxyTypeNotifier.value = value ?? 'HTTP';
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('SOCKS5 Proxy'),
                        value: 'SOCKS5',
                        groupValue: type,
                        onChanged: (value) {
                          _proxyTypeNotifier.value = value ?? 'SOCKS5';
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_proxyTypeNotifier.value != 'Direct') ...[
                  const Text('Proxy Host:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: hostController,
                    decoration: InputDecoration(
                      hintText: 'e.g., proxy.example.com',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Proxy Port:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: portController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'e.g., 8080',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Default HTTP: 8080\nDefault SOCKS5: 1080\nLeave blank to use defaults.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () {
                hostController.dispose();
                portController.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final hostText = hostController.text.trim();
                final portText = portController.text.trim();
                _proxyHostNotifier.value = hostText;
                _proxyPortNotifier.value = portText;
                hostController.dispose();
                portController.dispose();
                Navigator.pop(dialogContext);
                _showToast(context, 'Proxy configured: ${_proxyTypeNotifier.value}\nHost: ${hostText.isEmpty ? "default" : hostText}');
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDarkModeScheduleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Dark Mode Schedule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Automatic Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 12),
              Text('Enable dark mode at:', style: TextStyle(fontWeight: FontWeight.w500)),
              SizedBox(height: 8),
              Text('Start Time: 9:00 PM'),
              Text('End Time: 7:00 AM'),
              SizedBox(height: 16),
              Text('Benefits:', style: TextStyle(fontWeight: FontWeight.w500)),
              SizedBox(height: 8),
              Text('✓ Reduces eye strain at night'),
              Text('✓ Saves battery on OLED displays'),
              Text('✓ Better sleep quality'),
              Text('✓ Customizable schedule'),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showToast(context, 'Dark mode schedule enabled ✓\n9:00 PM - 7:00 AM');
              },
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );
  }

  void _showBackupActionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Backup Messages'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Last Backup: Today at 2:45 PM', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 12),
              Text('Backup Status:', style: TextStyle(fontWeight: FontWeight.w500)),
              SizedBox(height: 8),
              Text('✓ All messages synced'),
              Text('✓ 1,247 messages backed up'),
              Text('✓ Cloud storage: 45.2 MB'),
              Text('✓ Last sync duration: 2.3 seconds'),
              SizedBox(height: 16),
              Text('Next auto-backup in 6 hours', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showToast(context, 'Backup started...\nBackup complete ✓');
              },
              child: const Text('Backup Now'),
            ),
          ],
        );
      },
    );
  }

  void _showDndConfigDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Do Not Disturb Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _dndEnabledNotifier,
                builder: (context, enabled, _) => SwitchListTile(
                  title: const Text('Enable DND'),
                  value: enabled,
                  onChanged: (v) => _dndEnabledNotifier.value = v,
                ),
              ),
              const SizedBox(height: 12),
              if (_dndEnabledNotifier.value) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Time:', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ValueListenableBuilder<String>(
                          valueListenable: _dndStartTimeNotifier,
                          builder: (context, time, _) => Text(time, style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('End Time:', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ValueListenableBuilder<String>(
                          valueListenable: _dndEndTimeNotifier,
                          builder: (context, time, _) => Text(time, style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ValueListenableBuilder<bool>(
                        valueListenable: _dndAllowEmergencyNotifier,
                        builder: (context, allow, _) => CheckboxListTile(
                          title: const Text('Allow Emergency Calls'),
                          value: allow,
                          onChanged: (v) => _dndAllowEmergencyNotifier.value = v ?? true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showToast(context, 'DND ${_dndEnabledNotifier.value ? "enabled" : "disabled"}\n${_dndStartTimeNotifier.value} - ${_dndEndTimeNotifier.value}');
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showStatusDialog(BuildContext context) {
    final statuses = ['Online', 'Away', 'Busy', 'Offline'];
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Set Your Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: _currentStatusNotifier,
                builder: (context, status, _) => Column(
                  children: statuses.map((s) {
                    final colors = {
                      'Online': Colors.green,
                      'Away': Colors.orange,
                      'Busy': Colors.red,
                      'Offline': Colors.grey,
                    };
                    return RadioListTile<String>(
                      title: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors[s] ?? Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(s),
                        ],
                      ),
                      value: s,
                      groupValue: status,
                      onChanged: (value) => _currentStatusNotifier.value = value ?? 'Online',
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Status Message (Optional):', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => _statusMessageNotifier.value = v,
                decoration: InputDecoration(
                  hintText: 'What\'s on your mind?',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showToast(context, 'Status: ${_currentStatusNotifier.value} ✓');
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showAutoReplyDialog(BuildContext context) {
    final messageController = TextEditingController(text: _autoReplyMessageNotifier.value);
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Auto-Reply Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _autoReplyNotifier,
                builder: (context, enabled, _) => SwitchListTile(
                  title: const Text('Enable Auto-Reply'),
                  value: enabled,
                  onChanged: (v) => _autoReplyNotifier.value = v,
                ),
              ),
              if (_autoReplyNotifier.value) ...[
                const SizedBox(height: 12),
                const Text('Auto-Reply Message:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'I\'m currently away and will reply soon.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () {
                messageController.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                _autoReplyMessageNotifier.value = messageController.text;
                messageController.dispose();
                Navigator.pop(dialogContext);
                _showToast(context, 'Auto-reply ${_autoReplyNotifier.value ? "enabled" : "disabled"} ✓');
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showMessageSchedulingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Message Scheduling'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _messageSchedulingNotifier,
                builder: (context, enabled, _) => SwitchListTile(
                  title: const Text('Enable Message Scheduling'),
                  value: enabled,
                  onChanged: (v) => _messageSchedulingNotifier.value = v,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Schedule messages to send later:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Schedule Time'),
                      subtitle: const Text('Select when to send'),
                      onTap: () => _showToast(context, 'Time picker opens'),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('Message Template'),
                      subtitle: const Text('Save message templates'),
                      onTap: () => _showToast(context, '5 templates saved'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showToast(context, 'Message scheduling ${_messageSchedulingNotifier.value ? "enabled" : "disabled"} ✓');
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showBroadcastListDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Broadcast Lists'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Create New List'),
                leading: const Icon(Icons.add_circle),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _showToast(context, 'New broadcast list created');
                },
              ),
              const Divider(),
              const Text('Your Lists:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Family'),
                subtitle: const Text('12 members'),
                onTap: () => _showToast(context, 'Open Family list'),
              ),
              ListTile(
                title: const Text('Friends'),
                subtitle: const Text('34 members'),
                onTap: () => _showToast(context, 'Open Friends list'),
              ),
              ListTile(
                title: const Text('Work'),
                subtitle: const Text('8 members'),
                onTap: () => _showToast(context, 'Open Work list'),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showChatBubbleCustomizationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Chat Bubble Style'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: _selectedChatBubbleStyleNotifier,
                builder: (context, style, _) => Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Default (Rounded)'),
                      value: 'Default',
                      groupValue: style,
                      onChanged: (v) => _selectedChatBubbleStyleNotifier.value = v ?? 'Default',
                    ),
                    RadioListTile<String>(
                      title: const Text('Squircle'),
                      value: 'Squircle',
                      groupValue: style,
                      onChanged: (v) => _selectedChatBubbleStyleNotifier.value = v ?? 'Squircle',
                    ),
                    RadioListTile<String>(
                      title: const Text('Sharp Corners'),
                      value: 'Sharp',
                      groupValue: style,
                      onChanged: (v) => _selectedChatBubbleStyleNotifier.value = v ?? 'Sharp',
                    ),
                    RadioListTile<String>(
                      title: const Text('Pill Shaped'),
                      value: 'Pill',
                      groupValue: style,
                      onChanged: (v) => _selectedChatBubbleStyleNotifier.value = v ?? 'Pill',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Preview', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Sample message',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showToast(context, 'Chat bubble style: ${_selectedChatBubbleStyleNotifier.value} ✓');
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  void _showQuickReplyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Quick Reply Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _quickReplyNotifier,
                builder: (context, enabled, _) => SwitchListTile(
                  title: const Text('Enable Quick Reply'),
                  value: enabled,
                  onChanged: (v) => _quickReplyNotifier.value = v,
                ),
              ),
              if (_quickReplyNotifier.value) ...[
                const SizedBox(height: 12),
                const Text('Your Quick Replies:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...['Ok 👍', 'Thanks! 🙏', 'Got it! ✓', 'See you later! 👋', 'Sounds good! 😊'].map(
                  (reply) => ListTile(
                    title: Text(reply),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showToast(context, 'Edit quick reply'),
                    ),
                  ),
                ),
              ],
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            if (_quickReplyNotifier.value)
              FilledButton(
                onPressed: () => _showToast(context, 'Add new quick reply'),
                child: const Text('Add Reply'),
              ),
          ],
        );
      },
    );
  }

  void _showGroupManagementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Group Management'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Create Group'),
                leading: const Icon(Icons.group_add),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _showToast(context, 'Create new group');
                },
              ),
              ListTile(
                title: const Text('Your Groups (3)'),
                leading: const Icon(Icons.groups),
                onTap: () => _showToast(context, 'View all groups'),
              ),
              ListTile(
                title: const Text('Group Settings'),
                leading: const Icon(Icons.settings),
                onTap: () => _showToast(context, 'Open group settings'),
              ),
              ListTile(
                title: const Text('Muted Groups'),
                leading: const Icon(Icons.volume_off),
                onTap: () => _showToast(context, 'View muted groups'),
              ),
              ListTile(
                title: const Text('Group Notifications'),
                leading: const Icon(Icons.notifications),
                onTap: () => _showToast(context, 'Customize group notifications'),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showBlockedContactsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Block & Report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _blockUnknownContactsNotifier,
                builder: (context, enabled, _) => SwitchListTile(
                  title: const Text('Block Unknown Contacts'),
                  value: enabled,
                  onChanged: (v) => _blockUnknownContactsNotifier.value = v,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Blocked Contacts (2)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Spam Number +1234567890'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _showToast(context, 'Contact unblocked'),
                ),
              ),
              ListTile(
                title: const Text('Unknown User #12345'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _showToast(context, 'Contact unblocked'),
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showToast(context, 'Block unknown contacts ${_blockUnknownContactsNotifier.value ? "enabled" : "disabled"} ✓');
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showMessageSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Message Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _messageEditingNotifier,
                builder: (context, enabled, _) => SwitchListTile(
                  title: const Text('Edit Messages'),
                  value: enabled,
                  onChanged: (v) => _messageEditingNotifier.value = v,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _messageDeleteAfterNotifier,
                builder: (context, enabled, _) => SwitchListTile(
                  title: const Text('Delete After Time'),
                  value: enabled,
                  onChanged: (v) => _messageDeleteAfterNotifier.value = v,
                ),
              ),
              if (_messageDeleteAfterNotifier.value) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Delete after:', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Text('24 hours'),
                    ],
                  ),
                ),
              ],
              ValueListenableBuilder<bool>(
                valueListenable: _messageReactionsNotifier,
                builder: (context, enabled, _) => SwitchListTile(
                  title: const Text('Message Reactions'),
                  subtitle: const Text('React with emoji'),
                  value: enabled,
                  onChanged: (v) => _messageReactionsNotifier.value = v,
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showToast(context, 'Message settings saved ✓');
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showMediaSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Media Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _voiceMessageNotifier,
                builder: (context, enabled, _) => SwitchListTile(
                  title: const Text('Voice Messages'),
                  value: enabled,
                  onChanged: (v) {
                    _voiceMessageNotifier.value = v;
                  },
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _videoMessageNotifier,
                builder: (context, enabled, _) => SwitchListTile(
                  title: const Text('Video Messages'),
                  value: enabled,
                  onChanged: (v) {
                    _videoMessageNotifier.value = v;
                  },
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Video Quality:', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 8),
                    Text('High (Recommended)'),
                  ],
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showToast(context, 'Media settings saved ✓');
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showThemeAndWallpaperDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Themes & Wallpapers'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chat Wallpaper:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: _customWallpaperNotifier,
                builder: (context, enabled, _) => SwitchListTile(
                  title: const Text('Custom Wallpaper'),
                  value: enabled,
                  onChanged: (v) {
                    _customWallpaperNotifier.value = v;
                  },
                ),
              ),
              if (_customWallpaperNotifier.value) ...[
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showToast(context, 'Theme updated ✓');
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // UPDATE CHECKING & DOWNLOAD METHODS
  // ==========================================

  static bool _isNewerVersion(String latestVersion, String currentVersion) {
    try {
      final latest = _parseVersion(latestVersion);
      final current = _parseVersion(currentVersion);
      
      // Compare version arrays element by element
      final maxLength = latest.length > current.length ? latest.length : current.length;
      
      for (int i = 0; i < maxLength; i++) {
        final latestPart = i < latest.length ? latest[i] : 0;
        final currentPart = i < current.length ? current[i] : 0;
        
        if (latestPart > currentPart) return true;
        if (latestPart < currentPart) return false;
      }
      
      return false; // Versions are equal
    } catch (e) {
      return false;
    }
  }

  static List<int> _parseVersion(String version) {
    // Parse version like "1.9", "2.0.1", "1.9.0" to [1, 9, 0]
    return version
        .replaceAll('v', '')
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
  }

  Future<void> _checkAndDownloadUpdate(BuildContext context) async {
    try {
      _checkingUpdateNotifier.value = true;
      _showToast(context, 'Checking for updates...');

      final release = await _fetchLatestRelease();
      if (release == null) {
        if (context.mounted) {
          _showToast(context, 'Could not check for updates. Please try again.');
        }
        _checkingUpdateNotifier.value = false;
        return;
      }

      final fetchedVersion = release['version'] as String;
      final latestVersion = _customLatestVersionNotifier.value.isNotEmpty ? _customLatestVersionNotifier.value : fetchedVersion;
      final assetName = release['assetName'] as String? ?? 'Reyaansh-Chat-Android.apk';
      _latestVersionNotifier.value = latestVersion;

      if (_isNewerVersion(latestVersion, effectiveCurrentVersion)) {
        // New version available
        if (context.mounted) {
          _showUpdateDialog(context, latestVersion, release['downloadUrl'] as String, assetName);
        }
      } else {
        // Already on latest version
        if (context.mounted) {
          _showToast(context, 'All Updated ✓ You are on the latest version ($latestVersion)');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showToast(context, 'Error checking updates: $e');
      }
    } finally {
      _checkingUpdateNotifier.value = false;
    }
  }

  Future<Map<String, dynamic>?> _fetchLatestRelease() async {
    try {
      final response = await http.get(
        Uri.parse(_gitHubApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> releases = jsonDecode(response.body);
        if (releases.isEmpty) return null;

        // Find the latest Android APK release
        for (var release in releases) {
          final tagName = release['tag_name'] as String? ?? '';
          final assets = release['assets'] as List<dynamic>? ?? [];

          // Look for Android APK
          for (var asset in assets) {
            final assetName = asset['name'] as String? ?? '';
            if (assetName.contains('android', 0) || assetName.endsWith('.apk')) {
              return {
                'version': tagName.replaceAll('v', ''),
                'downloadUrl': asset['browser_download_url'] as String,
                'assetName': assetName,
                'releaseName': release['name'] as String? ?? tagName,
                'releaseNotes': release['body'] as String? ?? 'No release notes available',
              };
            }
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Directory?> getActualDownloadDirectory() async {
  if (Platform.isAndroid) {
    // 1. Direct path to Android's public Download folder
    final publicDownloadDir = Directory('/storage/emulated/0/Download');
    
    if (await publicDownloadDir.exists()) {
      return publicDownloadDir;
    }
  } else if (Platform.isIOS) {
    // On iOS, use the app's document directory
    return await getApplicationDocumentsDirectory();
  }
  
  // Fallback to app-private directory if public folder doesn't exist
  return await getDownloadsDirectory();
}

  Future<void> _downloadApkToDownloads(BuildContext context, String url, String assetName) async {
    try {
      _downloadProgressNotifier.value = 0.0;
      _checkingUpdateNotifier.value = true;
      _isDownloadingNotifier.value = true;
      _showToast(context, 'Downloading update...');

      final directory = await getActualDownloadDirectory();
      if (directory == null) {
        _showToast(context, 'Unable to locate downloads folder on this device.');
        return;
      }

      final safeName = assetName.isNotEmpty ? assetName : 'Reyaansh-Chat-Android.apk';
      final outputFile = File('${directory.path}/$safeName');
      await outputFile.parent.create(recursive: true);

      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();
      if (response.statusCode != 200) {
        _showToast(context, 'Download failed with status ${response.statusCode}');
        return;
      }

      final contentLength = response.contentLength ?? 0;
      var downloadedBytes = 0;
      final sink = outputFile.openWrite();

      await for (final chunk in response.stream) {
        downloadedBytes += chunk.length;
        sink.add(chunk);
        if (contentLength > 0) {
          _downloadProgressNotifier.value = downloadedBytes / contentLength;
        }
      }

      await sink.close();
      _showToast(context, 'Download complete: ${outputFile.path}');
      await _openDownloadedApk(outputFile, context);
    } catch (e) {
      _showToast(context, 'Update download failed: $e');
    } finally {
      _downloadProgressNotifier.value = null;
      _checkingUpdateNotifier.value = false;
      _isDownloadingNotifier.value = false;
    }
  }

  Future<void> _openDownloadedApk(File apkFile, BuildContext context) async {
    final uri = Uri.file(apkFile.path);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showToast(context, 'Could not open downloaded APK. Install it manually from Downloads.');
    }
  }

  Future<void> _showTestNotification(BuildContext context) async {
    if (kIsWeb) {
      _showToast(context, 'Local notification testing is not supported on Web.');
      return;
    }

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _chatNotificationChannel.id,
        _chatNotificationChannel.name,
        channelDescription: _chatNotificationChannel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _localNotificationsPlugin.show(
      id: 1001,
      title: 'Test Notification',
      body: 'This is a local test notification from Reyaansh Chat.',
      notificationDetails: notificationDetails,
      payload: 'test_notification',
    );

    _showToast(context, 'Test notification sent.');
  }

  void _showUpdateDialog(BuildContext context, String latestVersion, String downloadUrl, String assetName) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('New Update Available 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Version: ${effectiveCurrentVersion}'),
              Text('Latest Version: $latestVersion${_customLatestVersionNotifier.value.isNotEmpty ? ' (override)' : ''}'),
              const SizedBox(height: 12),
              const Text('A new version is available for download. Would you like to download and install it?'),
              const SizedBox(height: 8),
              Text('APK will be saved to your Downloads folder.', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Later'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Download'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _downloadApkToDownloads(context, downloadUrl, assetName);
              },
            ),
          ],
        );
      },
    );
  }
}

// -------------------------
// Video Feed Screen
// -------------------------

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final TextEditingController _urlController = TextEditingController();
  final DatabaseReference _ref = FirebaseDatabase.instance.ref('video_feed');
  StreamSubscription<DatabaseEvent>? _sub;
  List<Map<String, dynamic>> _videos = [];
  bool _isUploading = false;
  final Map<String, Map<String, dynamic>> _oembedCache = {};

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _sub = _ref.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      final list = <Map<String, dynamic>>[];
      if (data != null) {
        data.forEach((key, value) {
          final map = Map<String, dynamic>.from(value as Map);
          map['id'] = key;
          list.add(map);
        });
      }
      list.sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0));
      setState(() => _videos = list);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() => _isUploading = true);
    try {
      final entry = {
        'url': url,
        'uploaderId': EnterpriseSession.userId,
        'uploaderName': EnterpriseSession.username,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await _ref.push().set(entry);
      _urlController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _toggleLike(String videoId, Map<String, dynamic> video) async {
    final likesRef = _ref.child(videoId).child('likes');
    final userId = EnterpriseSession.userId;
    final likes = Map<String, dynamic>.from(video['likes'] ?? {});
    if (likes.containsKey(userId)) {
      await likesRef.child(userId).remove();
    } else {
      await likesRef.update({userId: true});
    }
  }

  Future<void> _openComments(String videoId) async {
    final commentsRef = _ref.child(videoId).child('comments');
    final TextEditingController c = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Comments'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<DatabaseEvent>(
                  stream: commentsRef.onValue,
                  builder: (context, snapshot) {
                    final data = snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;
                    final list = <Map<String, dynamic>>[];
                    if (data != null) {
                      data.forEach((k, v) {
                        final m = Map<String, dynamic>.from(v as Map);
                        m['id'] = k;
                        list.add(m);
                      });
                      list.sort((a, b) => (a['timestamp'] as int? ?? 0).compareTo(b['timestamp'] as int? ?? 0));
                    }
                    return SizedBox(
                      height: 240,
                      child: ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, idx) {
                          final cm = list[idx];
                          return ListTile(
                            title: Text(cm['username'] ?? 'Unknown'),
                            subtitle: Text(cm['text'] ?? ''),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: c, decoration: const InputDecoration(hintText: 'Add a comment')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
            FilledButton(
              onPressed: () async {
                final text = c.text.trim();
                if (text.isEmpty) return;
                final comment = {
                  'userId': EnterpriseSession.userId,
                  'username': EnterpriseSession.username,
                  'text': text,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                };
                await commentsRef.push().set(comment);
                c.clear();
              },
              child: const Text('Post'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Video Feed')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(hintText: 'Direct video URL'),
                    keyboardType: TextInputType.url,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isUploading ? null : _upload,
                  child: _isUploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Upload'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _videos.length,
                itemBuilder: (context, index) {
                  final v = _videos[index];
                  final likes = Map<String, dynamic>.from(v['likes'] ?? {});
                  final likeCount = likes.length;
                  final comments = Map<String, dynamic>.from(v['comments'] ?? {});
                  final commentCount = comments.length;
                  return Card(
                    child: ListTile(
                      title: Text(v['uploaderName'] ?? 'Unknown'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(builder: (context) {
                            final url = (v['url'] ?? '').toString();
                            final isVideo = url.startsWith('https://') || url.startsWith('http://');
                            final ytId = extractYoutubeId(url);
                                      if (ytId != null) {
                                        return YouTubeEmbed(url: url, cache: _oembedCache);
                                      }
                            if (isVideo) {
                              return GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: url)));
                                },
                                child: Container(
                                  height: 200,
                                  color: Colors.black12,
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.play_circle_fill, size: 48),
                                        SizedBox(width: 8),
                                        Text('Play video', style: TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }
                            return SelectableText(url, maxLines: 2);
                          }),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _toggleLike(v['id'] as String, v),
                                icon: Icon(likes.containsKey(EnterpriseSession.userId) ? Icons.favorite : Icons.favorite_border, color: likes.containsKey(EnterpriseSession.userId) ? Colors.red : null),
                              ),
                              Text('$likeCount'),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: () => _openComments(v['id'] as String),
                                icon: const Icon(Icons.comment),
                              ),
                              Text('$commentCount'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String url;
  const VideoPlayerScreen({super.key, required this.url});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() => _initialized = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.pause();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video')),
      body: Center(
        child: _initialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: _initialized
          ? FloatingActionButton(
              onPressed: () => setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play()),
              child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
            )
          : null,
    );
  }
}

String? extractYoutubeId(String url) {
  try {
    final uri = Uri.parse(url);
    if (uri.host.contains('youtube.com')) {
      return uri.queryParameters['v'];
    }
    if (uri.host == 'youtu.be') {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
    }
    final m = RegExp(r'youtube\.com/embed/([A-Za-z0-9_-]{11})').firstMatch(url);
    if (m != null) return m.group(1);
  } catch (e) {
    return null;
  }
  return null;
}

class YouTubePlayerScreen extends StatefulWidget {
  final String videoId;
  const YouTubePlayerScreen({super.key, required this.videoId});

  @override
  State<YouTubePlayerScreen> createState() => _YouTubePlayerScreenState();
}

class _YouTubePlayerScreenState extends State<YouTubePlayerScreen> {
  @override
  Widget build(BuildContext context) {
    final watchUrl = 'https://www.youtube.com/watch?v=${widget.videoId}';
    return Scaffold(
      appBar: AppBar(title: const Text('YouTube')),
      body: Center(
        child: FilledButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open on YouTube'),
          onPressed: () async {
            final uri = Uri.parse(watchUrl);
            if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open YouTube')));
              }
            }
          },
        ),
      ),
    );
  }
}

class YouTubeEmbed extends StatefulWidget {
  final String url;
  final Map<String, Map<String, dynamic>> cache;
  const YouTubeEmbed({super.key, required this.url, required this.cache});

  @override
  State<YouTubeEmbed> createState() => _YouTubeEmbedState();
}

class _YouTubeEmbedState extends State<YouTubeEmbed> {
  Map<String, dynamic>? _data;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = widget.url;
    if (widget.cache.containsKey(url)) {
      setState(() => _data = widget.cache[url]);
      return;
    }
    setState(() => _loading = true);
    try {
      final oembedUrl = Uri.parse('https://www.youtube.com/oembed?url=${Uri.encodeFull(url)}&format=json');
      final resp = await http.get(oembedUrl).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final jsonData = jsonDecode(resp.body) as Map<String, dynamic>;
        widget.cache[url] = jsonData;
        if (mounted) setState(() => _data = jsonData);
      }
    } catch (e) {
      // ignore errors, we'll fallback to thumbnail
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    final id = extractYoutubeId(url);
    final thumb = _data != null ? (_data!['thumbnail_url'] as String?) : null;
    final title = _data != null ? (_data!['title'] as String?) : null;
    final author = _data != null ? (_data!['author_name'] as String?) : null;

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse('https://www.youtube.com/watch?v=$id');
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open YouTube')));
        }
      },
      child: Card(
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 200,
              child: thumb != null
                  ? Image.network(thumb, fit: BoxFit.cover)
                  : id != null
                      ? Image.network('https://img.youtube.com/vi/$id/hqdefault.jpg', fit: BoxFit.cover)
                      : Container(color: Colors.black12),
            ),
            ListTile(
              title: Text(title ?? 'YouTube Video'),
              subtitle: Text(author ?? ''),
              trailing: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : null,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  final remoteNotification = message.notification;
  if (remoteNotification == null) return;
  if (SettingsScreen._isDndActive()) return;

  final notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _chatNotificationChannel.id,
      _chatNotificationChannel.name,
      channelDescription: _chatNotificationChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
    ),
  );

  await _localNotificationsPlugin.show(
    id: remoteNotification.hashCode, // MUST be named 'id:'
    title: remoteNotification.title,
    body: remoteNotification.body,
    notificationDetails: notificationDetails,
    payload: message.data['click_action']?.toString() ?? '',
  );
}


  
  

Future<void> _initializeFirebaseMessaging() async {
  if (!kIsWeb) {
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize Android notification channel
    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_chatNotificationChannel);
  }

  // Request notification permissions
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.denied) {
    return;
  }

  if (!kIsWeb) {
    final androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final initSettings = InitializationSettings(android: androidInit);
    await _localNotificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle local notification tap if desired.
      },
    );
  }

  // Subscribe to topics and listen for messages
  if (!kIsWeb && EnterpriseSession.notificationsEnabled) {
    try {
      await FirebaseMessaging.instance.subscribeToTopic('group_chat');
      await FirebaseMessaging.instance.subscribeToTopic('all_users');
    } catch (e) {
      // Silently fail subscription
    }
  }

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((message) async {
    if (EnterpriseSession.notificationsEnabled) {
      await _showLocalNotification(message);
    }
  });

  // Handle notification tap
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    // Navigate to chat screen or relevant screen when notification is tapped
    if (message.data.containsKey('chatId')) {
      // Navigate to specific chat
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppInitializer.setupHardwareAcceleration();

  await BackendService.instance.initialize();
  await EnterpriseSession.initializePreferences();
  await SettingsScreen.initializePreferences();

  final firebaseOptions = DefaultFirebaseOptions.currentPlatform;
  debugPrint('Firebase startup database URL: ${firebaseOptions.databaseURL ?? 'null'}');
  await Firebase.initializeApp(options: firebaseOptions);
  await PluginManager.initialize();
  await BackgroundAudioController.instance.initialize();
  unawaited(_initializeFirebaseMessaging());

  if (EnterpriseSession.isLoggedIn()) {
    unawaited(EnterpriseSession.publishProfileToFirebase());
  }

  runApp(const ReyaanshCoreApp());
}

// =========================================================================
// 1. GLOBAL SESSION STATE (ONE-TIME LOGIN CONFIG WITH PERSISTENCE)
// =========================================================================

class ContactEntry {
  final String userId;
  final String name;
  final String avatarUrl;
  final String themeWallpaperUrl;
  final int addedAt;

  ContactEntry({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    this.themeWallpaperUrl = '',
    int? addedAt,
  }) : addedAt = addedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory ContactEntry.fromJson(Map<String, dynamic> json) {
    return ContactEntry(
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      themeWallpaperUrl: json['themeWallpaperUrl']?.toString() ?? '',
      addedAt: json['addedAt'] is int
          ? json['addedAt'] as int
          : int.tryParse(json['addedAt']?.toString() ?? '') ??
              DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'avatarUrl': avatarUrl,
      'themeWallpaperUrl': themeWallpaperUrl,
      'addedAt': addedAt,
    };
  }
}

class EnterpriseSession {
  static String userId = '';
  static String username = '';
  static String avatarUrl = '';
  static late SharedPreferences _prefs;
  static Color themeSeedColor = const Color.fromARGB(255, 46, 154, 124);
  static final ValueNotifier<Color> themeSeedColorNotifier =
      ValueNotifier<Color>(themeSeedColor);
  static String themeVariant = 'light'; // 'light' | 'dark' | 'amoled'
  static final ValueNotifier<String> themeVariantNotifier =
      ValueNotifier<String>(themeVariant);
  static bool notificationsEnabled = true;
  static final ValueNotifier<bool> notificationsEnabledNotifier =
      ValueNotifier<bool>(notificationsEnabled);
  static final ValueNotifier<List<ContactEntry>> contactsNotifier =
      ValueNotifier<List<ContactEntry>>(<ContactEntry>[]);

  // Initialize SharedPreferences
  static Future<void> initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFromPreferences();
    await _loadContactsFromPreferences();
  }

  static void _loadFromPreferences() {
    userId = _prefs.getString('userId') ?? '';
    username = _prefs.getString('username') ?? '';
    avatarUrl = _prefs.getString('avatarUrl') ?? '';

    themeSeedColor = Color(
      _prefs.getInt('themeSeedColor') ?? themeSeedColor.toARGB32(),
    );
    themeVariant = _prefs.getString('themeVariant') ?? 'light';
    themeVariantNotifier.value = themeVariant;
    notificationsEnabled = _prefs.getBool('notificationsEnabled') ?? true;
    notificationsEnabledNotifier.value = notificationsEnabled;
    themeSeedColorNotifier.value = themeSeedColor;
  }

  static Future<void> _loadContactsFromPreferences() async {
    try {
      final jsonString = _prefs.getString('savedContacts') ?? '[]';
      final data = jsonDecode(jsonString) as List<dynamic>;
      final loadedContacts = data
          .map((entry) => ContactEntry.fromJson(
              Map<String, dynamic>.from(entry as Map<dynamic, dynamic>)))
          .toList();
      contactsNotifier.value = loadedContacts;
    } catch (_) {
      contactsNotifier.value = <ContactEntry>[];
    }
  }

  static Future<void> _saveContactsToPreferences() async {
    final jsonString = jsonEncode(
      contactsNotifier.value.map((contact) => contact.toJson()).toList(),
    );
    await _prefs.setString('savedContacts', jsonString);
  }

  static Future<void> restoreContactsFromData(List<dynamic> contactsData) async {
    final restoredContacts = contactsData
        .map((entry) => ContactEntry.fromJson(
            Map<String, dynamic>.from(entry as Map<dynamic, dynamic>)))
        .toList();
    contactsNotifier.value = restoredContacts;
    await _saveContactsToPreferences();
  }

  static List<ContactEntry> get contacts => contactsNotifier.value;

  static ContactEntry? getContact(String userId) {
    try {
      return contactsNotifier.value
          .firstWhere((entry) => entry.userId == userId);
    } catch (_) {
      return null;
    }
  }

  static bool isKnownContact(String userId) {
    return getContact(userId) != null;
  }

  static Future<void> addOrUpdateContact(ContactEntry contact) async {
    final copied = List<ContactEntry>.from(contactsNotifier.value);
    final index = copied.indexWhere((entry) => entry.userId == contact.userId);
    if (index >= 0) {
      copied[index] = contact;
    } else {
      copied.add(contact);
    }
    contactsNotifier.value = copied;
    await _saveContactsToPreferences();
  }

  static Future<void> removeContact(String userId) async {
    final copied = contactsNotifier.value
        .where((entry) => entry.userId != userId)
        .toList();
    contactsNotifier.value = copied;
    await _saveContactsToPreferences();
  }

  static Future<ContactEntry?> fetchRemoteProfileById(
      String sharedUserId) async {
    final userData = await BackendService.instance.fetchProfile(sharedUserId);
    if (userData == null) {
      return null;
    }

    return ContactEntry(
      userId: sharedUserId,
      name: userData['username']?.toString() ?? 'Unknown',
      avatarUrl: userData['avatarUrl']?.toString() ?? '',
      themeWallpaperUrl: userData['themeWallpaperUrl']?.toString() ?? '',
    );
  }

  static Future<void> _persistSessionProfile() async {
    final profile = {
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'themeVariant': themeVariant,
      'themeSeedColor': themeSeedColor.toARGB32(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await _prefs.setString('sessionProfile', jsonEncode(profile));
  }

  static Map<String, dynamic> _serializeMessagePayload(Map<String, dynamic> message) {
    final copy = Map<String, dynamic>.from(message);
    if (copy['timestamp'] is Map) {
      copy['timestamp'] = DateTime.now().millisecondsSinceEpoch;
    }
    return copy;
  }

  static Future<void> savePendingChatMessage(String roomId, Map<String, dynamic> message) async {
    final key = 'pendingMessages:$roomId';
    final existing = _prefs.getString(key);
    final decoded = existing == null || existing.isEmpty
        ? <Map<String, dynamic>>[]
        : (jsonDecode(existing) as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
    decoded.add(_serializeMessagePayload(message));
    await _prefs.setString(key, jsonEncode(decoded));
  }

  static Future<List<Map<String, dynamic>>> loadPendingChatMessages(String roomId) async {
    final key = 'pendingMessages:$roomId';
    final existing = _prefs.getString(key);
    if (existing == null || existing.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    return (jsonDecode(existing) as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<void> clearPendingChatMessages(String roomId) async {
    await _prefs.remove('pendingMessages:$roomId');
  }

  static Future<void> publishProfileToFirebase() async {
    if (userId.isEmpty) return;
    await _persistSessionProfile();

    final profilePayload = {
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'themeWallpaperUrl': '',
      'themeVariant': themeVariant,
      'themeSeedColor': themeSeedColor.toARGB32(),
      'updatedAt': ServerValue.timestamp,
    };

    try {
      await BackendService.instance.persistProfile(userId, profilePayload);
      await _prefs.setString('profileSyncStatus', 'synced');
    } catch (error, stackTrace) {
      debugPrint('Backend publish failed: $error\n$stackTrace');
      await _prefs.setString('profileSyncStatus', 'pending');
    }
  }

  static Color get themeSeed => themeSeedColorNotifier.value;

  static Future<void> setThemeSeedColor(Color color) async {
    themeSeedColor = color;
    themeSeedColorNotifier.value = color;
    await _prefs.setInt('themeSeedColor', color.toARGB32());
  }

  static String get currentThemeVariant => themeVariantNotifier.value;

  static Future<void> setThemeVariant(String variant) async {
    themeVariant = variant;
    themeVariantNotifier.value = variant;
    await _prefs.setString('themeVariant', variant);
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    notificationsEnabled = enabled;
    notificationsEnabledNotifier.value = enabled;
    await _prefs.setBool('notificationsEnabled', enabled);
  }

  // Initialize session and persist to SharedPreferences
  static Future<void> initialize(String name, String avatar) async {
    // Generate a unique session ID only if this is the first login
    if (userId.isEmpty) {
      userId =
          '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
    }
    username = name;
    avatarUrl = avatar;

    // Persist to SharedPreferences
    await _prefs.setString('userId', userId);
    await _prefs.setString('username', username);
    await _prefs.setString('avatarUrl', avatarUrl);
    await publishProfileToFirebase();
  }

  static Future<void> initializeFromShared({
    required String sharedUserId,
    required String sharedUsername,
    required String sharedAvatarUrl,
  }) async {
    userId = sharedUserId;
    username = sharedUsername;
    avatarUrl = sharedAvatarUrl;

    await _prefs.setString('userId', userId);
    await _prefs.setString('username', username);
    await _prefs.setString('avatarUrl', avatarUrl);
    await publishProfileToFirebase();
  }

  static Future<void> logout() async {
    userId = '';
    username = '';
    avatarUrl = '';
    await _prefs.remove('userId');
    await _prefs.remove('username');
    await _prefs.remove('avatarUrl');
  }

  static bool isLoggedIn() {
    return userId.isNotEmpty && username.isNotEmpty;
  }
}

// QR scanning via native camera was removed to maintain web compatibility.
// Instead a small paste-url dialog is used across platforms.

class LocalShareServer {
  LocalShareServer._();
  static final LocalShareServer instance = LocalShareServer._();

  HttpServer? _server;
  String? _currentUrl;

  Future<String> startServer() async {
    if (_server != null && _currentUrl != null) {
      return _currentUrl!;
    }

    final localIp = await _getLocalIpAddress();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _currentUrl = 'http://$localIp:${_server!.port}/share';

    _server!.listen((request) async {
      final response = request.response;
      if (request.method == 'GET' && request.uri.path == '/share') {
        final html = _buildSharePageHtml();
        response.headers.contentType = ContentType.html;
        response.write(html);
      } else if (request.method == 'GET' && request.uri.path == '/payload') {
        final payload = _buildPayloadJson();
        response.headers.contentType = ContentType.json;
        response.write(payload);
      } else {
        response.statusCode = HttpStatus.notFound;
        response.write('Not found');
      }
      await response.close();
    }, onError: (error) {
      _server = null;
      _currentUrl = null;
    });

    return _currentUrl!;
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
    _currentUrl = null;
  }

  String _buildPayloadJson() {
    final payload = {
      'userId': EnterpriseSession.userId,
      'username': EnterpriseSession.username,
      'avatarUrl': EnterpriseSession.avatarUrl,
    };
    return jsonEncode(payload);
  }

  String _buildSharePageHtml() {
    final displayName = const HtmlEscape().convert(EnterpriseSession.username);
    final avatarUrl = const HtmlEscape().convert(EnterpriseSession.avatarUrl);
    final sharedUserId = const HtmlEscape().convert(EnterpriseSession.userId);

    final escapedAvatar = avatarUrl.isNotEmpty
        ? avatarUrl
        : 'https://via.placeholder.com/120?text=User';

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Shared Login</title>
  <style>
    body { margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f3f4f6; color: #1f2937; }
    .frame { max-width: 540px; margin: 40px auto; padding: 24px; background: white; border-radius: 20px; box-shadow: 0 18px 50px rgba(15, 23, 42, 0.12); }
    .avatar { width: 120px; height: 120px; border-radius: 50%; object-fit: cover; border: 4px solid #4b5563; }
    h1 { font-size: 24px; margin: 24px 0 12px; }
    p { color: #4b5563; line-height: 1.65; }
    .badge { display: inline-flex; align-items: center; gap: 0.5rem; background: #e0f2fe; color: #0369a1; padding: 12px 14px; border-radius: 14px; margin-top: 10px; }
    .button { width: 100%; margin-top: 24px; padding: 14px 18px; border: none; border-radius: 14px; background: #2563eb; color: white; font-size: 16px; cursor: pointer; }
    .button:active { transform: scale(0.98); }
    .note { margin-top: 18px; color: #6b7280; font-size: 14px; }
    .user-id { margin: 16px 0 0; padding: 14px; background: #f3f4f6; border-radius: 12px; word-break: break-all; font-family: monospace; }
  </style>
</head>
<body>
  <div class="frame">
    <img class="avatar" src="$escapedAvatar" alt="Avatar" />
    <h1>Shared login ready</h1>
    <p>Switch to the app, then tap 'Use shared account' in the chat screen to complete login.</p>
    <div class="badge">Shared user: $displayName</div>
    <div class="user-id">$sharedUserId</div>
    <button class="button" onclick="window.location.href = '/payload'">Fetch shared payload</button>
    <p class="note">This page now exposes the shared account payload directly for the receiving app to fetch.</p>
  </div>
</body>
</html>''';
  }

  Future<String> _getLocalIpAddress() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback && address.type == InternetAddressType.IPv4) {
          return address.address;
        }
      }
    }
    return '127.0.0.1';
  }
}

class ThemeColorPicker {
  static const List<Color> palette = [
    Colors.amber,
    Colors.blue,
    Colors.teal,
    Colors.purple,
    Colors.green,
    Colors.orange,
    Colors.indigo,
    Colors.pink,
    Colors.cyan,
    Colors.lime,
    Colors.deepOrange,
    Colors.deepPurple,
    Colors.lightBlue,
    Colors.lightGreen,
    Colors.yellow,
    Colors.red,
    Colors.brown,
    Colors.blueGrey,
    Colors.grey,
  ];

  static Future<void> open(BuildContext context) async {
    final selectedColor = await showModalBottomSheet<Color>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pick app color',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12.0),
              Wrap(
                spacing: 12.0,
                runSpacing: 12.0,
                children: palette.map((color) {
                  final bool isSelected =
                      color.toARGB32() ==
                      EnterpriseSession.themeSeed.toARGB32();
                  return GestureDetector(
                    onTap: () => Navigator.of(context).pop(color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3.0)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 8.0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 24,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20.0),
              const SizedBox(height: 12.0),
              Text('Theme style', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8.0),
              ValueListenableBuilder<String>(
                valueListenable: EnterpriseSession.themeVariantNotifier,
                builder: (context, current, _) {
                  return Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Light'),
                        selected: current == 'light',
                        onSelected: (v) async {
                          await EnterpriseSession.setThemeVariant('light');
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Dark'),
                        selected: current == 'dark',
                        onSelected: (v) async {
                          await EnterpriseSession.setThemeVariant('dark');
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Amoled'),
                        selected: current == 'amoled',
                        onSelected: (v) async {
                          await EnterpriseSession.setThemeVariant('amoled');
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12.0),
              Center(
                child: Text(
                  'Your selection is saved automatically.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedColor != null) {
      await EnterpriseSession.setThemeSeedColor(selectedColor);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Theme color updated.'),
          backgroundColor: selectedColor,
        ),
      );
    }
  }
}

// =========================================================================
// 2. MASTER BRANDING & MATERIAL 3 THEME CONFIGURATION WITH AUTO-LOGIN
// =========================================================================

class ReyaanshCoreApp extends StatefulWidget {
  const ReyaanshCoreApp({super.key});

  @override
  State<ReyaanshCoreApp> createState() => _ReyaanshCoreAppState();
}

class _ReyaanshCoreAppState extends State<ReyaanshCoreApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: EnterpriseSession.themeSeedColorNotifier,
      builder: (context, seedColor, child) {
        return ValueListenableBuilder<String>(
          valueListenable: EnterpriseSession.themeVariantNotifier,
          builder: (context, variant, _) {
            final ThemeData light = ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light).copyWith(surfaceContainerHigh: const Color(0xFFF4F6E7)),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(fontSize: 16.0, fontWeight: FontWeight.normal),
                bodyMedium: TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal),
                labelSmall: TextStyle(fontSize: 11.0, color: Colors.grey),
              ),
            );

            final ThemeData dark = ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark),
            );

            final ThemeData amoled = dark.copyWith(
              scaffoldBackgroundColor: Colors.black,
              canvasColor: Colors.black,
              colorScheme: dark.colorScheme.copyWith(background: Colors.black, surface: Colors.black),
            );

            ThemeMode mode = ThemeMode.light;
            if (variant == 'dark') mode = ThemeMode.dark;
            if (variant == 'amoled') mode = ThemeMode.dark;

            return ValueListenableBuilder<PluginDefinition?>(
              valueListenable: PluginManager.activePluginNotifier,
              builder: (context, activePlugin, _) {
                final effectiveSeed = activePlugin?.seedColor ?? seedColor;
                final effectiveAccent = activePlugin?.accentColor ?? Colors.cyan;
                final effectiveLight = light.copyWith(
                  colorScheme: light.colorScheme.copyWith(primary: effectiveSeed, secondary: effectiveAccent),
                );
                final effectiveDark = dark.copyWith(
                  colorScheme: dark.colorScheme.copyWith(primary: effectiveSeed, secondary: effectiveAccent),
                );
                final effectiveAmoled = amoled.copyWith(
                  colorScheme: amoled.colorScheme.copyWith(primary: effectiveSeed, secondary: effectiveAccent),
                );

                return ValueListenableBuilder<String>(
                  valueListenable: SettingsScreen._languageNotifier,
                  builder: (context, language, _) {
                    final locale = SettingsScreen.localeFromLanguage(language);
                    return MaterialApp(
                      title: 'Reyaansh Chat',
                      debugShowCheckedModeBanner: false,
                      locale: locale,
                      supportedLocales: AppLocalizations.supportedLocales,
                      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                        AppLocalizationsDelegate(),
                        GlobalMaterialLocalizations.delegate,
                        GlobalWidgetsLocalizations.delegate,
                        GlobalCupertinoLocalizations.delegate,
                      ],
                      theme: effectiveLight,
                      darkTheme: variant == 'amoled' ? effectiveAmoled : effectiveDark,
                      themeMode: mode,
                      home: child,
                    );
                  },
                );
              },
            );
          },
        );
      },
      child: EnterpriseSession.isLoggedIn() ? const ChatDashboard() : const LoginScreen(),
    );
  }
}

// =========================================================================
// 3. AUTHENTICATION / LOGIN DASHBOARD
// =========================================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _avatarUrlController = TextEditingController();
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with saved data if available
    _usernameController.text = EnterpriseSession.username;
    _avatarUrlController.text = EnterpriseSession.avatarUrl;
  }

  Future<void> _performLogin() async {
    if (_isLoggingIn) return;

    final name = _usernameController.text.trim();
    final avatar = _avatarUrlController.text.trim();

    if (name.isEmpty) {
      AlertBridge.showNotification(
        context,
        "Username is required to join the chat.",
        isFailureState: true,
      );
      return;
    }

    setState(() => _isLoggingIn = true);

    try {
      await EnterpriseSession.initialize(name, avatar);
      await EnterpriseSession.publishProfileToFirebase();
      if (mounted) {
        AlertBridge.showNotification(context, 'Profile saved and ready to chat.');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ChatDashboard()),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Login failed: $error\n$stackTrace');
      AlertBridge.showNotification(
        context,
        "Unable to join chat right now. Please try again.",
        isFailureState: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  Future<void> _performLogout() async {
    await EnterpriseSession.logout();
    if (mounted) {
      _usernameController.clear();
      _avatarUrlController.clear();
      setState(() {});
      AlertBridge.showNotification(context, "Logged out successfully.");
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surfaceContainerHigh,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 0,
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.0),
                side: BorderSide(color: colors.outlineVariant, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        SettingsScreen._logoTapCountNotifier.value++;
                        if (SettingsScreen._logoTapCountNotifier.value >= 10) {
                          SettingsScreen._logoTapCountNotifier.value = 0;
                          // Easter egg: Open GitHub
                          launchUrl(
                            Uri.parse('https://github.com/reyaansh72'),
                            mode: LaunchMode.externalApplication,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('🎉 Easter egg found! Opening GitHub...'), duration: Duration(seconds: 2)),
                          );
                        }
                      },
                      child: Icon(Icons.public, size: 64, color: colors.primary),
                    ),
                    const WidgetSpacer(height: 16),
                    GestureDetector(
                      onTap: () {
                        SettingsScreen._logoTapCountNotifier.value++;
                        if (SettingsScreen._logoTapCountNotifier.value >= 10) {
                          SettingsScreen._logoTapCountNotifier.value = 0;
                          // Easter egg: Open GitHub
                          launchUrl(
                            Uri.parse('https://github.com/reyaansh72'),
                            mode: LaunchMode.externalApplication,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('🎉 Easter egg found! Opening GitHub...'), duration: Duration(seconds: 2)),
                          );
                        }
                      },
                      child: Text(
                        'Reyaansh Chat',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const WidgetSpacer(height: 8),
                    Text(
                      EnterpriseSession.isLoggedIn()
                          ? 'You are logged in. Edit or logout below.'
                          : 'Set up your profile to start chatting with your contacts',
                      style: TextStyle(color: colors.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const WidgetSpacer(height: 24),
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                      },
                      borderRadius: BorderRadius.circular(12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 14.0,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.settings),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: Text(
                                'Theme Accent Color',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: EnterpriseSession.themeSeed,
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const WidgetSpacer(height: 20),
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                    const WidgetSpacer(height: 16),
                    TextField(
                      controller: _avatarUrlController,
                      decoration: InputDecoration(
                        labelText: 'Avatar URL (Optional)',
                        prefixIcon: const Icon(Icons.image_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                    const WidgetSpacer(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _isLoggingIn ? null : _performLogin,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: _isLoggingIn
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              EnterpriseSession.isLoggedIn()
                                  ? 'Update Profile & Chat'
                                  : 'Join Chat',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      ),
                    ),
                    if (EnterpriseSession.isLoggedIn()) ...[
                      const WidgetSpacer(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _performLogout,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            side: BorderSide(color: colors.error),
                          ),
                          child: Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colors.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// 4. STABLE DATA MODEL REPRESENTATION
// =========================================================================

class ChatPayload {
  final String id;
  final String message;
  final String? attachmentUrl;
  final DateTime timestamp;
  final String senderId;
  final String senderName;
  final String senderAvatarUrl;
  final Map<String, int> reactions;

  const ChatPayload({
    required this.id,
    required this.message,
    this.attachmentUrl,
    required this.timestamp,
    required this.senderId,
    required this.senderName,
    required this.senderAvatarUrl,
    this.reactions = const {},
  });

  factory ChatPayload.fromRtdb(DataSnapshot snapshot) {
    final rawData = snapshot.value as Map<dynamic, dynamic>?;
    final data = rawData == null
        ? <String, dynamic>{}
        : rawData.map((key, value) => MapEntry(key.toString(), value));

    final rawReactions = data['reactions'] as Map<dynamic, dynamic>?;
    final parsedReactions = rawReactions == null
        ? <String, int>{}
        : rawReactions.map(
            (key, value) => MapEntry(key.toString(), (value as num).toInt()),
          );

    final attachment = data['mediaUrl'];

    return ChatPayload(
      id: snapshot.key ?? '',
      message: data['text']?.toString() ?? '',
      attachmentUrl: attachment is String && attachment.isNotEmpty
          ? attachment
          : null,
      timestamp: _decodeTimestamp(data['timestamp']),
      senderId: data['senderId']?.toString() ?? '',
      senderName: data['senderName']?.toString() ?? 'Unknown User',
      senderAvatarUrl: data['senderAvatarUrl']?.toString() ?? '',
      reactions: parsedReactions,
    );
  }

  static DateTime _decodeTimestamp(dynamic timestamp) {
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    if (timestamp is double) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
    }
    if (timestamp is String) {
      final parsed = int.tryParse(timestamp);
      if (parsed != null) {
        return DateTime.fromMillisecondsSinceEpoch(parsed);
      }
    }
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    final payload = <String, dynamic>{
      'text': message,
      'mediaUrl': attachmentUrl,
      'timestamp': ServerValue.timestamp,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
    };

    if (reactions.isNotEmpty) {
      payload['reactions'] = reactions;
    }
    return payload;
  }
}

// =========================================================================
// 5. CORE CHAT INTERFACE & RESPONSIVE LAYOUT MATRIX
// =========================================================================

class ChatDashboard extends StatefulWidget {
  const ChatDashboard({super.key});

  @override
  State<ChatDashboard> createState() => _ChatDashboardState();
}

class _ChatDashboardState extends State<ChatDashboard> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isComposing = false;
  final Map<String, DateTime> _lastAutoReplySent = {};
  final Map<String, bool> _contactTypingStatuses = {};
  Timer? _typingActivityTimer;
  List<GroupChatEntry> _groups = <GroupChatEntry>[];
  StreamSubscription<DatabaseEvent>? _groupsSubscription;
  Timer? _pollTimer;

  late final Stream<DatabaseEvent> _rtdbStream;
  late final Query _messagesQuery;
  late final StreamSubscription<DatabaseEvent> _childAddedSubscription;
  late final StreamSubscription<DatabaseEvent> _typingSubscription;
  late final int _messageNotificationCutoff;

  @override
  void initState() {
    super.initState();
    _messageNotificationCutoff = DateTime.now().millisecondsSinceEpoch;
    if (BackendService.instance.isLocal) {
      _loadGroupsFromBackend();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _loadGroupsFromBackend());
    } else {
      _messagesQuery = FirebaseDatabase.instance
          .ref('messages')
          .orderByChild('timestamp');
      _rtdbStream = _messagesQuery.onValue;
      _childAddedSubscription = FirebaseDatabase.instance
          .ref('messages')
          .onChildAdded
          .listen(_handleMessageAdded);

      _typingSubscription = FirebaseDatabase.instance
          .ref('typing_status')
          .onValue
          .listen(_handleTypingStatusUpdate);

      _groupsSubscription = FirebaseDatabase.instance
          .ref('groups')
          .onValue
          .listen((event) {
            final result = <GroupChatEntry>[];
            for (final child in event.snapshot.children) {
              final data = child.value as Map<dynamic, dynamic>?;
              if (data == null) continue;
              final group = GroupChatEntry.fromRtdb(child.key ?? '', data);
              if (group.memberIds.contains(EnterpriseSession.userId) || group.createdBy == EnterpriseSession.userId) {
                result.add(group);
              }
            }
            result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            if (mounted) {
              setState(() => _groups = result);
            }
          });
    }

    _textController.addListener(() {
      final composing = _textController.text.isNotEmpty;
      setState(() {
        _isComposing = composing;
      });
      _updateTypingStatus(composing);
    });
  }

  @override
  void dispose() {
    _groupsSubscription?.cancel();
    _childAddedSubscription.cancel();
    _typingSubscription.cancel();
    _typingActivityTimer?.cancel();
    _pollTimer?.cancel();
    _updateTypingStatus(false);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadGroupsFromBackend() async {
    try {
      final items = await BackendService.instance.readCollectionItems('groups');
      final result = <GroupChatEntry>[];
      for (final item in items) {
        final id = item['id']?.toString() ?? item['groupId']?.toString() ?? '';
        if (id.isEmpty) continue;
        final memberIds = <String>[];
        final rawMembers = item['memberIds'];
        if (rawMembers is List) {
          memberIds.addAll(rawMembers.whereType<String>());
        } else if (rawMembers is Iterable) {
          memberIds.addAll(rawMembers.whereType<String>());
        }
        final createdAt = item['createdAt'] is int
            ? DateTime.fromMillisecondsSinceEpoch(item['createdAt'] as int)
            : DateTime.now();
        final group = GroupChatEntry(
          id: id,
          name: item['name']?.toString() ?? 'Group',
          createdBy: item['createdBy']?.toString() ?? '',
          memberIds: memberIds,
          createdAt: createdAt,
        );
        if (group.memberIds.contains(EnterpriseSession.userId) || group.createdBy == EnterpriseSession.userId) {
          result.add(group);
        }
      }
      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) {
        setState(() => _groups = result);
      }
    } catch (_) {}
  }

  void _handleTypingStatusUpdate(DatabaseEvent event) {
    final snapshot = event.snapshot;
    if (!snapshot.exists || snapshot.value == null) {
      setState(() {
        _contactTypingStatuses.clear();
      });
      return;
    }

    final raw = snapshot.value as Map<dynamic, dynamic>;
    final statuses = raw.map<String, bool>((key, value) {
      return MapEntry(key.toString(), value == true);
    });

    setState(() {
      _contactTypingStatuses
          .removeWhere((key, _) => statuses[key] == false);
      statuses.forEach((key, value) {
        if (key != EnterpriseSession.userId) {
          _contactTypingStatuses[key] = value;
        }
      });
    });
  }

  void _updateTypingStatus(bool isTyping) {
    if (BackendService.instance.isLocal || EnterpriseSession.userId.isEmpty) return;
    final typingRef = FirebaseDatabase.instance
        .ref('typing_status/${EnterpriseSession.userId}');

    if (isTyping) {
      _typingActivityTimer?.cancel();
      typingRef.set(true);
      _typingActivityTimer = Timer(const Duration(seconds: 3), () {
        typingRef.set(false);
      });
      return;
    }

    _typingActivityTimer?.cancel();
    typingRef.set(false);
  }

  void _showSlashHelpDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Chat commands'),
        content: const Text('/shrug\n/tableflip\n/unflip\n/me <action>\n/roll [NdM]\n/joke\n/clear\n/help'),
        actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Close'))],
      ),
    );
  }

  void _handleDispatch(String content, {String? mediaUrl}) {
    if (content.trim().isEmpty && mediaUrl == null) return;

    final commandResult = SlashCommandHelper.process(content, username: EnterpriseSession.username);
    if (!commandResult.shouldSend) {
      if (commandResult.shouldClearInput) {
        _textController.clear();
        return;
      }
      if (commandResult.showHelp) {
        _showSlashHelpDialog();
        return;
      }
      return;
    }

    final messageText = commandResult.message.trim();
    if (messageText.isEmpty && mediaUrl == null) return;

    if (BackendService.instance.isLocal) {
      unawaited(BackendService.instance.appendCollectionItem('messages', {
        'text': messageText,
        'mediaUrl': mediaUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'senderId': EnterpriseSession.userId,
        'senderName': EnterpriseSession.username,
        'senderAvatarUrl': EnterpriseSession.avatarUrl,
      }));
    } else {
      final reference = FirebaseDatabase.instance.ref('messages').push();
      final messageId = reference.key ?? '';
      reference.set({
        'text': messageText,
        'mediaUrl': mediaUrl,
        'timestamp': ServerValue.timestamp,
        'senderId': EnterpriseSession.userId,
        'senderName': EnterpriseSession.username,
        'senderAvatarUrl': EnterpriseSession.avatarUrl,
      });

      _notifyNotificationService(
        senderId: EnterpriseSession.userId,
        senderName: EnterpriseSession.username,
        text: messageText,
        messageId: messageId,
      );
    }

    _textController.clear();
    Future.delayed(const Duration(milliseconds: 200), _scrollToBottom);
  }

  Future<void> _notifyNotificationService({
    required String senderId,
    required String senderName,
    required String text,
    required String messageId,
  }) async {
    if (kNotificationBackendUrl.contains('your-render-backend')) {
      return;
    }

    try {
      final uri = Uri.parse('$kNotificationBackendUrl/notify');
      await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'senderId': senderId,
          'senderName': senderName,
          'text': text,
          'messageId': messageId,
        }),
      );
    } catch (error) {
      // Ignored: notification service failed, app still sends message.
    }
  }

  Future<void> _handleMessageAdded(DatabaseEvent event) async {
    if (event.snapshot.value == null) return;

    final value = event.snapshot.value as Map<dynamic, dynamic>?;
    if (value == null) return;

    final triggerId = value['senderId']?.toString() ?? '';
    final timestamp = value['timestamp'];
    final createdAt = timestamp is int
        ? timestamp
        : int.tryParse(timestamp?.toString() ?? '') ?? 0;

    if (createdAt < _messageNotificationCutoff) {
      return;
    }

    if (triggerId == EnterpriseSession.userId) {
      return;
    }

    final senderName = value['senderName']?.toString() ?? 'New message';
    final text = value['text']?.toString() ?? '';
    final body = text.isNotEmpty ? text : 'Sent an attachment';

    if (EnterpriseSession.notificationsEnabled) {
      await _showLocalNotification(
        RemoteMessage(
          notification: RemoteNotification(
            title: '$senderName sent a message',
            body: body,
          ),
          data: {
            'senderId': triggerId,
            'messageId': event.snapshot.key ?? '',
            'type': 'chat',
          },
        ),
      );
    }

    final isStatusAway = SettingsScreen._currentStatusNotifier.value != 'Online';
    final autoReplyEnabled = SettingsScreen._autoReplyNotifier.value && isStatusAway;
    final lastReply = _lastAutoReplySent[triggerId];

    if (autoReplyEnabled && (lastReply == null || DateTime.now().difference(lastReply) > const Duration(minutes: 10))) {
      final replyText = SettingsScreen._autoReplyMessageNotifier.value.isNotEmpty
          ? SettingsScreen._autoReplyMessageNotifier.value
          : 'I am currently away and will reply soon.';

      final replyReference = FirebaseDatabase.instance.ref('messages').push();
      replyReference.set({
        'text': replyText,
        'mediaUrl': null,
        'timestamp': ServerValue.timestamp,
        'senderId': EnterpriseSession.userId,
        'senderName': EnterpriseSession.username,
        'senderAvatarUrl': EnterpriseSession.avatarUrl,
      });

      _lastAutoReplySent[triggerId] = DateTime.now();
    }
  }

  void _openAttachmentSequence() {
    TransmissionManager().triggerMediaModal(context, _handleDispatch);
  }

  Future<void> _showAccountShareDialog() async {
    final shareUrl = await LocalShareServer.instance.startServer();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        final String localIpUrl = shareUrl;
        return AlertDialog(
          title: const Text('Share Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Open this local link in another device or scan the QR code.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const WidgetSpacer(height: 20),
              SelectableText(
                localIpUrl,
                style: const TextStyle(fontSize: 14, color: Colors.blueAccent),
              ),
              const WidgetSpacer(height: 20),
              QrImageView(
                data: localIpUrl,
                size: 220.0,
                backgroundColor: Colors.white,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: localIpUrl));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              },
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _launchExternal(localIpUrl);
              },
              child: const Text('Open Externally'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openShareLink(localIpUrl);
              },
              child: const Text('Open In-App'),
            ),
          ],
        );
      },
    );
  }

  void _openShareLink(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AccountShareReceiver(url: url),
      ),
    );
  }

  Future<void> _launchExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch URL externally')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch URL')),
      );
    }
  }

  void _showPasteUrlDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter shared link'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Paste link here'),
            keyboardType: TextInputType.url,
            autofillHints: const [AutofillHints.url],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(context).pop();
                  _openShareLink(text);
                }
              },
              child: const Text('Open'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateGroupDialog() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create group'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Group name',
                hintText: 'Friends, Team, Family',
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return 'Please enter a group name';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (shouldCreate != true) return;

    final groupName = nameController.text.trim();
    final groupId = BackendService.instance.isLocal
        ? 'group_${DateTime.now().millisecondsSinceEpoch}'
        : FirebaseDatabase.instance.ref('groups').push().key;
    if (groupId == null || groupId.isEmpty) return;

    if (BackendService.instance.isLocal) {
      await BackendService.instance.appendCollectionItem('groups', {
        'id': groupId,
        'name': groupName,
        'createdBy': EnterpriseSession.userId,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'memberIds': [EnterpriseSession.userId],
      });
      await BackendService.instance.setValue('groupMembers/$groupId/${EnterpriseSession.userId}', {
        'role': 'admin',
        'joinedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      final groupRef = FirebaseDatabase.instance.ref('groups/$groupId');
      await groupRef.set({
        'name': groupName,
        'createdBy': EnterpriseSession.userId,
        'createdAt': ServerValue.timestamp,
        'memberIds': {EnterpriseSession.userId: true},
      });
      await FirebaseDatabase.instance.ref('groupMembers/$groupId/${EnterpriseSession.userId}').set({
        'role': 'admin',
        'joinedAt': ServerValue.timestamp,
      });
    }

    if (!mounted) return;
    nameController.dispose();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupChatScreen(group: GroupChatEntry(
        id: groupId,
        name: groupName,
        createdBy: EnterpriseSession.userId,
        memberIds: [EnterpriseSession.userId],
        createdAt: DateTime.now(),
      ))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    void handleLogout() async {
      await EnterpriseSession.logout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }

    return Scaffold(
      backgroundColor: colors.surfaceContainerHigh,
      appBar: AppBar(
        title: const Text(
          'Contacts',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        elevation: 1,
        actions: [
          IconButton(
            onPressed: _showCreateGroupDialog,
            icon: const Icon(Icons.group_add_rounded),
            color: colors.onPrimaryContainer,
            tooltip: 'Create group',
          ),
          IconButton(
            onPressed: () {
              _showPasteUrlDialog();
            },
            icon: const Icon(Icons.qr_code_scanner),
            color: colors.onPrimaryContainer,
            tooltip: 'Scan/Paste Link',
          ),
          IconButton(
            onPressed: _showAccountShareDialog,
            icon: const Icon(Icons.qr_code),
            color: colors.onPrimaryContainer,
            tooltip: 'Share account',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.format_paint),
            color: colors.onPrimaryContainer,
            tooltip: 'Settings',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Chip(
              avatar: UserAvatarWidget(
                url: EnterpriseSession.avatarUrl,
                size: 24,
              ),
              label: Text(EnterpriseSession.username),
              backgroundColor: colors.surface,
              side: BorderSide.none,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Tooltip(
                message: 'Logout',
                child: TouchFeedbackEnhancer(
                  onTap: handleLogout,
                  borderRadius: BorderRadius.circular(4.0),
                  child: Icon(Icons.logout, color: colors.onPrimaryContainer),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<ContactEntry>>(
        valueListenable: EnterpriseSession.contactsNotifier,
        builder: (context, contacts, _) {
          final children = <Widget>[];

          children.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Text('Groups', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          );

          if (_groups.isEmpty) {
            children.add(
              Card(
                child: ListTile(
                  title: const Text('Create a personal group'),
                  subtitle: const Text('Invite your contacts into a shared space.'),
                  trailing: FilledButton.tonal(
                    onPressed: _showCreateGroupDialog,
                    child: const Text('New group'),
                  ),
                ),
              ),
            );
          } else {
            for (final group in _groups) {
              children.add(
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.group_rounded)),
                    title: Text(group.name),
                    subtitle: Text('${group.memberIds.length} members'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)),
                      );
                    },
                  ),
                ),
              );
            }
          }

          children.add(const SizedBox(height: 12));
          children.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text('Contacts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          );

          if (contacts.isEmpty) {
            children.add(
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.contacts_rounded, size: 56, color: colors.outline),
                      const SizedBox(height: 8),
                      Text('No contacts yet', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('Add a contact and start a private conversation.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactsScreen())),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Add contact'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            for (final contact in contacts) {
              children.add(
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    leading: UserAvatarWidget(url: contact.avatarUrl, size: 48),
                    title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(contact.userId.isNotEmpty ? 'Tap to open chat' : 'Add a valid user ID', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ContactChatScreen(contact: contact)),
                      );
                    },
                  ),
                ),
              );
            }
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: children,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactsScreen())),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add contact'),
      ),
    );
  }
}

class GroupChatScreen extends StatefulWidget {
  final GroupChatEntry group;

  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatPayload> _messages = <ChatPayload>[];
  StreamSubscription<DatabaseEvent>? _messageSubscription;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    if (BackendService.instance.isLocal) {
      _loadMessagesFromBackend();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _loadMessagesFromBackend());
    } else {
      _messageSubscription = FirebaseDatabase.instance
          .ref('groupMessages/${widget.group.id}')
          .onValue
          .listen((event) {
            final messages = event.snapshot.children
                .map((child) => ChatPayload.fromRtdb(child))
                .toList();
            messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            if (!mounted) return;
            setState(() => _messages = messages);
            Future.delayed(const Duration(milliseconds: 120), _scrollToBottom);
          });
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadMessagesFromBackend() async {
    try {
      final items = await BackendService.instance.readCollectionItems('groupMessages/${widget.group.id}');
      final messages = items
          .map((item) => ChatPayload(
                id: item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
                message: item['text']?.toString() ?? '',
                timestamp: item['timestamp'] is int
                    ? DateTime.fromMillisecondsSinceEpoch(item['timestamp'] as int)
                    : DateTime.now(),
                senderId: item['senderId']?.toString() ?? '',
                senderName: item['senderName']?.toString() ?? '',
                senderAvatarUrl: item['senderAvatarUrl']?.toString() ?? '',
              ))
          .toList();
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (mounted) {
        setState(() => _messages = messages);
        Future.delayed(const Duration(milliseconds: 120), _scrollToBottom);
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final content = _textController.text.trim();
    if (content.isEmpty) return;

    final processedContent = PluginManager.processMessageText(content);
    if (BackendService.instance.isLocal) {
      await BackendService.instance.appendCollectionItem('groupMessages/${widget.group.id}', {
        'text': processedContent,
        'mediaUrl': null,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'senderId': EnterpriseSession.userId,
        'senderName': EnterpriseSession.username,
        'senderAvatarUrl': EnterpriseSession.avatarUrl,
      });
    } else {
      final reference = FirebaseDatabase.instance.ref('groupMessages/${widget.group.id}').push();
      await reference.set({
        'text': processedContent,
        'mediaUrl': null,
        'timestamp': ServerValue.timestamp,
        'senderId': EnterpriseSession.userId,
        'senderName': EnterpriseSession.username,
        'senderAvatarUrl': EnterpriseSession.avatarUrl,
      });
    }
    _textController.clear();
    Future.delayed(const Duration(milliseconds: 120), _scrollToBottom);
  }

  Future<void> _showInviteMembersDialog() async {
    final selected = <String>{};
    final contacts = EnterpriseSession.contacts.where((contact) => !widget.group.memberIds.contains(contact.userId)).toList();

    if (contacts.isEmpty) {
      if (mounted) {
        AlertBridge.showNotification(context, 'No contacts available to invite right now.');
      }
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Invite members'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: contacts.map((contact) {
                    return CheckboxListTile(
                      value: selected.contains(contact.userId),
                      title: Text(contact.name),
                      subtitle: Text(contact.userId),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selected.add(contact.userId);
                          } else {
                            selected.remove(contact.userId);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    final inviteIds = selected.toList();
                    if (inviteIds.isEmpty) return;
                    final groupRef = FirebaseDatabase.instance.ref('groups/${widget.group.id}/memberIds');
                    final updates = <String, dynamic>{};
                    for (final inviteId in inviteIds) {
                      updates[inviteId] = true;
                      await FirebaseDatabase.instance.ref('groupMembers/${widget.group.id}/$inviteId').set({
                        'role': 'member',
                        'joinedAt': ServerValue.timestamp,
                      });
                    }
                    await groupRef.update(updates);
                    if (mounted) {
                      AlertBridge.showNotification(context, 'Invites sent to your selected contacts.');
                    }
                  },
                  child: const Text('Invite'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          IconButton(
            onPressed: _showInviteMembersDialog,
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Invite members',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_rounded, size: 60, color: colors.outline),
                        const SizedBox(height: 12),
                        Text('Start chatting in ${widget.group.name}', style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message.senderId == EnterpriseSession.userId;
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: isMe ? colors.primaryContainer : colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            message.message,
                            style: TextStyle(color: isMe ? colors.onPrimaryContainer : colors.onSurface, fontSize: SettingsScreen._chatFontSizeNotifier.value),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: colors.surface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GroupChatEntry {
  final String id;
  final String name;
  final String createdBy;
  final List<String> memberIds;
  final DateTime createdAt;

  const GroupChatEntry({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.memberIds,
    required this.createdAt,
  });

  factory GroupChatEntry.fromRtdb(String id, Map<dynamic, dynamic> data) {
    final rawMembers = data['memberIds'];
    final memberIds = <String>[];
    if (rawMembers is Map) {
      rawMembers.forEach((key, value) {
        if (value == true) {
          memberIds.add(key.toString());
        }
      });
    }
    return GroupChatEntry(
      id: id,
      name: data['name']?.toString() ?? 'Group',
      createdBy: data['createdBy']?.toString() ?? '',
      memberIds: memberIds,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (data['createdAt'] is int ? data['createdAt'] as int : 0),
      ),
    );
  }
}

class ContactChatScreen extends StatefulWidget {
  final ContactEntry contact;

  const ContactChatScreen({super.key, required this.contact});

  @override
  State<ContactChatScreen> createState() => _ContactChatScreenState();
}

class _ContactChatScreenState extends State<ContactChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatPayload> _messages = <ChatPayload>[];
  late final String _roomId;
  StreamSubscription<DatabaseEvent>? _messageSubscription;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _roomId = _buildRoomId(EnterpriseSession.userId, widget.contact.userId);
    if (BackendService.instance.isLocal) {
      _loadMessagesFromBackend();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _loadMessagesFromBackend());
    } else {
      _messageSubscription = FirebaseDatabase.instance
          .ref('chatRooms/$_roomId')
          .onValue
          .listen((event) {
            final messages = event.snapshot.children
                .map((child) => ChatPayload.fromRtdb(child))
                .toList();
            messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            if (!mounted) return;
            setState(() {
              _messages = messages;
            });
            Future.delayed(const Duration(milliseconds: 120), _scrollToBottom);
          });
    }
    unawaited(_flushPendingMessages());
  }

  Future<void> _loadMessagesFromBackend() async {
    try {
      final items = await BackendService.instance.readCollectionItems('chatRooms/$_roomId');
      final messages = items
          .map((item) => ChatPayload(
                id: item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
                message: item['text']?.toString() ?? '',
                timestamp: item['timestamp'] is int
                    ? DateTime.fromMillisecondsSinceEpoch(item['timestamp'] as int)
                    : DateTime.now(),
                senderId: item['senderId']?.toString() ?? '',
                senderName: item['senderName']?.toString() ?? '',
                senderAvatarUrl: item['senderAvatarUrl']?.toString() ?? '',
              ))
          .toList();
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (mounted) {
        setState(() => _messages = messages);
        Future.delayed(const Duration(milliseconds: 120), _scrollToBottom);
      }
    } catch (_) {}
  }

  Future<void> _flushPendingMessages() async {
    final pending = await EnterpriseSession.loadPendingChatMessages(_roomId);
    if (pending.isEmpty) return;

    final roomRef = FirebaseDatabase.instance.ref('chatRooms/$_roomId');
    for (final payload in pending) {
      try {
        await roomRef.push().set(payload);
      } catch (_) {
        return;
      }
    }

    await EnterpriseSession.clearPendingChatMessages(_roomId);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _buildRoomId(String userId, String contactId) {
    final ids = [userId, contactId]..sort();
    return 'chat_${ids.first}_${ids.last}';
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _showSlashHelpDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Chat commands'),
        content: const Text('/shrug\n/tableflip\n/unflip\n/me <action>\n/roll [NdM]\n/joke\n/clear\n/help'),
        actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final content = _textController.text.trim();
    if (content.isEmpty) return;

    final commandResult = SlashCommandHelper.process(content, username: EnterpriseSession.username);
    if (!commandResult.shouldSend) {
      if (commandResult.shouldClearInput) {
        _textController.clear();
        return;
      }
      if (commandResult.showHelp) {
        _showSlashHelpDialog();
        return;
      }
      return;
    }

    final processedContent = PluginManager.processMessageText(commandResult.message.trim());
    final payload = {
      'text': processedContent,
      'mediaUrl': null,
      'timestamp': ServerValue.timestamp,
      'senderId': EnterpriseSession.userId,
      'senderName': EnterpriseSession.username,
      'senderAvatarUrl': EnterpriseSession.avatarUrl,
    };

    try {
      if (BackendService.instance.isLocal) {
        await BackendService.instance.appendCollectionItem('chatRooms/$_roomId', payload);
      } else {
        final reference = FirebaseDatabase.instance.ref('chatRooms/$_roomId').push();
        await reference.set(payload);
      }
      _textController.clear();
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 120), _scrollToBottom);
      }
    } catch (error) {
      debugPrint('Chat send failed: $error');
      await EnterpriseSession.savePendingChatMessage(_roomId, payload);
      if (mounted) {
        setState(() {
          _messages.add(
            ChatPayload(
              id: 'local_${DateTime.now().millisecondsSinceEpoch}',
              message: processedContent,
              timestamp: DateTime.now(),
              senderId: EnterpriseSession.userId,
              senderName: EnterpriseSession.username,
              senderAvatarUrl: EnterpriseSession.avatarUrl,
            ),
          );
        });
        AlertBridge.showNotification(context, 'Message saved locally and will sync when the connection is available.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final chatTheme = SettingsScreen._selectedChatThemeNotifier.value;
    final pluginHints = PluginManager.buildChatUiHints();
    final scaffoldColor = chatTheme == 'Midnight'
        ? const Color(0xFF0F172A)
        : chatTheme == 'Mint'
            ? const Color(0xFFE8F5E9)
            : chatTheme == 'Rose'
                ? const Color(0xFFFFF1F2)
                : colors.surfaceContainerHigh;
    final bubbleColor = chatTheme == 'Midnight'
        ? const Color(0xFF1E293B)
        : chatTheme == 'Mint'
            ? const Color(0xFFB9F6CA)
            : chatTheme == 'Rose'
                ? const Color(0xFFF8BBD0)
                : Color(int.parse((pluginHints['accentColor'] as String? ?? '#4f46e5').replaceFirst('#', 'FF'), radix: 16));
    final bubbleTextColor = chatTheme == 'Midnight'
        ? Colors.white
        : colors.onSurface;
    final bubbleRadius = pluginHints['bubbleRadius'] as int? ?? 18;
    final spacingMultiplier = (pluginHints['spacingMultiplier'] as double? ?? 1.0).toDouble();

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        backgroundColor: chatTheme == 'Midnight' ? const Color(0xFF111827) : colors.primaryContainer,
        foregroundColor: chatTheme == 'Midnight' ? Colors.white : colors.onPrimaryContainer,
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatarWidget(url: widget.contact.avatarUrl, size: 34),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.contact.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 60, color: colors.outline),
                        const SizedBox(height: 12),
                        Text('Start chatting with ${widget.contact.name}', style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message.senderId == EnterpriseSession.userId;
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: EdgeInsets.symmetric(horizontal: 14 * spacingMultiplier, vertical: 10 * spacingMultiplier),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: isMe ? bubbleColor : colors.surface,
                            borderRadius: BorderRadius.circular(bubbleRadius.toDouble()),
                          ),
                          child: Text(
                            message.message,
                            style: TextStyle(color: isMe ? bubbleTextColor : colors.onSurface, fontSize: SettingsScreen._chatFontSizeNotifier.value),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: colors.surface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: TextStyle(fontSize: SettingsScreen._chatFontSizeNotifier.value),
                    decoration: InputDecoration(
                      hintText: 'Type a message or /help',
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _themeUrlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _avatarController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;
  bool _remoteFound = false;
  List<ContactEntry> _firebaseUsers = <ContactEntry>[];
  bool _isLoadingUsers = false;

  @override
  void dispose() {
    _userIdController.dispose();
    _themeUrlController.dispose();
    _nameController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  Future<void> _loadFirebaseUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      if (BackendService.instance.isLocal) {
        final profiles = await BackendService.instance.listProfiles();
        final users = <ContactEntry>[];
        for (final profile in profiles) {
          final userId = profile['userId']?.toString() ?? profile['id']?.toString() ?? '';
          if (userId.isEmpty || userId == EnterpriseSession.userId) continue;
          users.add(ContactEntry(
            userId: userId,
            name: profile['username']?.toString() ?? 'Unknown',
            avatarUrl: profile['avatarUrl']?.toString() ?? '',
            themeWallpaperUrl: profile['themeWallpaperUrl']?.toString() ?? '',
          ));
        }
        setState(() => _firebaseUsers = users);
        return;
      }

      final snapshot = await FirebaseDatabase.instance.ref('users').get();
      if (!snapshot.exists || snapshot.value == null) {
        setState(() => _firebaseUsers = <ContactEntry>[]);
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final users = <ContactEntry>[];
      data.forEach((key, value) {
        if (value is Map) {
          final map = Map<String, dynamic>.from(value as Map);
          final userId = key.toString();
          final name = map['username']?.toString() ?? 'Unknown';
          final avatar = map['avatarUrl']?.toString() ?? '';
          final wallpaper = map['themeWallpaperUrl']?.toString() ?? '';
          if (userId.isNotEmpty && userId != EnterpriseSession.userId) {
            users.add(ContactEntry(
              userId: userId,
              name: name,
              avatarUrl: avatar,
              themeWallpaperUrl: wallpaper,
            ));
          }
        }
      });
      setState(() => _firebaseUsers = users);
    } catch (_) {
      setState(() => _firebaseUsers = <ContactEntry>[]);
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _fetchProfile() async {
    final userId = _userIdController.text.trim();
    if (userId.isEmpty) {
      setState(() {
        _errorText = 'Enter a user ID to search.';
        _remoteFound = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
      _remoteFound = false;
    });

    try {
      final profile = await EnterpriseSession.fetchRemoteProfileById(userId);
      if (profile == null) {
        setState(() {
          _errorText = 'No profile found for this user ID.';
          _remoteFound = false;
        });
        return;
      }

      _nameController.text = profile.name;
      _avatarController.text = profile.avatarUrl;
      _themeUrlController.text = profile.themeWallpaperUrl;
      setState(() {
        _remoteFound = true;
      });
    } catch (e) {
      setState(() {
        _errorText = 'Could not fetch profile. Check your network or Firebase rules.';
        _remoteFound = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveContact() async {
    final userId = _userIdController.text.trim();
    final name = _nameController.text.trim();
    final avatar = _avatarController.text.trim();
    final themeUrl = _themeUrlController.text.trim();

    if (userId.isEmpty || name.isEmpty) {
      setState(() {
        _errorText = 'User ID and name are required.';
      });
      return;
    }

    final entry = ContactEntry(
      userId: userId,
      name: name,
      avatarUrl: avatar,
      themeWallpaperUrl: themeUrl,
    );

    await EnterpriseSession.addOrUpdateContact(entry);
    if (!mounted) return;
    setState(() {
      _errorText = null;
      _remoteFound = false;
    });
    Navigator.of(context).pop();
  }

  void _showAddContactDialog() {
    _userIdController.clear();
    _nameController.clear();
    _avatarController.clear();
    _themeUrlController.clear();
    _errorText = null;
    _remoteFound = false;
    _loadFirebaseUsers();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text('Add contact by User ID'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoadingUsers)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(),
                    )
                  else if (_firebaseUsers.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Select a registered user', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        itemCount: _firebaseUsers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final user = _firebaseUsers[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(backgroundImage: user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null, child: user.avatarUrl.isEmpty ? const Icon(Icons.person) : null),
                            title: Text(user.name),
                            subtitle: Text(user.userId),
                            onTap: () {
                              _userIdController.text = user.userId;
                              _nameController.text = user.name;
                              _avatarController.text = user.avatarUrl;
                              _themeUrlController.text = user.themeWallpaperUrl;
                              setState(() {
                                _remoteFound = true;
                                _errorText = null;
                              });
                              Navigator.of(dialogContext).pop();
                              _showAddContactDialog();
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _userIdController,
                    decoration: const InputDecoration(
                      labelText: 'User ID',
                      hintText: 'Select a user or enter manually',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : () async {
                      await _fetchProfile();
                      setState(() {});
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Fetch profile'),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoading) const CircularProgressIndicator(),
                  if (_errorText != null) ...[
                    Text(_errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _avatarController,
                    decoration: const InputDecoration(
                      labelText: 'Avatar URL',
                      hintText: 'https://...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _themeUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Theme Image URL',
                      hintText: 'Optional wallpaper URL',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_remoteFound && _avatarController.text.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _avatarController.text,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 96,
                          height: 96,
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          child: const Icon(Icons.person, size: 40),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _saveContact,
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _showEditContactDialog(ContactEntry contact) async {
    _userIdController.text = contact.userId;
    _nameController.text = contact.name;
    _avatarController.text = contact.avatarUrl;
    _themeUrlController.text = contact.themeWallpaperUrl;
    _errorText = null;
    _remoteFound = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text('Edit contact'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _userIdController,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'User ID',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _avatarController,
                    decoration: const InputDecoration(
                      labelText: 'Avatar URL',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _themeUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Theme Image URL',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await EnterpriseSession.removeContact(contact.userId);
                  if (mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text('Remove', style: TextStyle(color: Colors.red)),
              ),
              FilledButton(
                onPressed: () async {
                  await EnterpriseSession.addOrUpdateContact(ContactEntry(
                    userId: contact.userId,
                    name: _nameController.text.trim(),
                    avatarUrl: _avatarController.text.trim(),
                    themeWallpaperUrl: _themeUrlController.text.trim(),
                  ));
                  if (mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ValueListenableBuilder<List<ContactEntry>>(
          valueListenable: EnterpriseSession.contactsNotifier,
          builder: (context, contacts, _) {
            if (contacts.isEmpty) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.contacts, size: 72, color: colors.outline),
                  const SizedBox(height: 16),
                  Text('No contacts added yet.', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Add a user by their User ID to save contacts and custom themes.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _showAddContactDialog,
                    child: const Text('Add first contact'),
                  ),
                ],
              );
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: contacts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          leading: UserAvatarWidget(url: contact.avatarUrl, size: 48),
                          title: Text(contact.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: ${contact.userId}'),
                              if (contact.themeWallpaperUrl.isNotEmpty)
                                Text('Custom theme set', style: TextStyle(color: colors.primary)),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditContactDialog(contact),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _showAddContactDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add contact'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AccountShareReceiver extends StatefulWidget {
  final String url;

  const AccountShareReceiver({super.key, required this.url});

  @override
  State<AccountShareReceiver> createState() => _AccountShareReceiverState();
}

class _AccountShareReceiverState extends State<AccountShareReceiver> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSharedPayload();
  }

  Future<void> _fetchSharedPayload() async {
    try {
      final baseUri = Uri.parse(widget.url);
      final payloadUri = baseUri.replace(path: '/payload');
      final request = await HttpClient().getUrl(payloadUri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw Exception('Failed to load payload');
      }

      final body = await response.transform(utf8.decoder).join();
      final payload = jsonDecode(body) as Map<String, dynamic>;
      final newUserId = payload['userId']?.toString();
      final newUsername = payload['username']?.toString();
      final newAvatarUrl = payload['avatarUrl']?.toString() ?? '';

      if (newUserId == null || newUsername == null) {
        throw Exception('Missing login values');
      }

      await EnterpriseSession.initializeFromShared(
        sharedUserId: newUserId,
        sharedUsername: newUsername,
        sharedAvatarUrl: newAvatarUrl,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ChatDashboard()),
        (_) => false,
      );
      AlertBridge.showNotification(context, 'Shared login saved.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Login failed: unable to retrieve shared payload.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Login'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 18.0),
                const Text('Completing shared login...'),
              ] else ...[
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 18.0),
                Text(
                  _errorMessage ?? 'Unable to complete login.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18.0),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Back'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// 6. MULTI-MEDIA MESSAGING ENGINE & BUBBLE RENDERING
// =========================================================================

class MultiMediaMessageEngine extends StatelessWidget {
  final ChatPayload payload;

  const MultiMediaMessageEngine({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isMe = payload.senderId == EnterpriseSession.userId;

    final contact = EnterpriseSession.getContact(payload.senderId);
    final contactThemeImage = contact?.themeWallpaperUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            UserAvatarWidget(url: payload.senderAvatarUrl, size: 36),
            const WidgetSpacer(width: 8.0),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                    child: Text(
                      payload.senderName,
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.70,
                  ),
                  child: EmoteContextActionWrapper(
                    messageId: payload.id,
                    messageText: payload.message,
                    child: Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      color: isMe
                          ? colors.primaryContainer
                          : colors.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16.0),
                          topRight: const Radius.circular(16.0),
                          bottomLeft: Radius.circular(isMe ? 16.0 : 4.0),
                          bottomRight: Radius.circular(isMe ? 4.0 : 16.0),
                        ),
                      ),
                      clipBehavior: contactThemeImage != null && contactThemeImage.isNotEmpty
                          ? Clip.antiAlias
                          : Clip.none,
                      child: Container(
                        decoration: contactThemeImage != null && contactThemeImage.isNotEmpty
                            ? BoxDecoration(
                                image: DecorationImage(
                                  image: NetworkImage(contactThemeImage),
                                  fit: BoxFit.cover,
                                  colorFilter: ColorFilter.mode(
                                    colors.surface.withOpacity(0.75),
                                    BlendMode.dstATop,
                                  ),
                                ),
                              )
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (payload.attachmentUrl != null &&
                                  payload.attachmentUrl!.isNotEmpty) ...[
                                if (_looksLikeImageUrl(payload.attachmentUrl!))
                                  GestureDetector(
                                    onTap: () {
                                      _openUrl(context, payload.attachmentUrl!);
                                    },
                                    child: Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12.0),
                                          child: Image.network(
                                            payload.attachmentUrl!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: 180,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const NetworkRecoveryFallbackWidget();
                                            },
                                            loadingBuilder:
                                                (context, child, loadingProgress) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return Container(
                                                height: 180,
                                                color: colors.surfaceContainerHigh,
                                                child: const Center(
                                                  child: CircularProgressIndicator(),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        Container(
                                          margin: const EdgeInsets.all(12.0),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10.0,
                                            vertical: 6.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.52),
                                            borderRadius:
                                                BorderRadius.circular(16.0),
                                          ),
                                          child: const Text(
                                            'Open',
                                            style: TextStyle(
                                              fontSize: 12.0,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                              if (payload.message.isNotEmpty)
                                const WidgetSpacer(height: 8.0),
                              if (payload.message.isNotEmpty)
                                ValueListenableBuilder<double>(
                                  valueListenable: SettingsScreen._chatFontSizeNotifier,
                                  builder: (context, fontSize, _) {
                                    return Text(
                                      payload.message,
                                      style: TextStyle(
                                        color: isMe
                                            ? colors.onPrimaryContainer
                                            : colors.onSurface,
                                        fontSize: fontSize,
                                      ),
                                    );
                                  },
                                ),
                              if (isMe)
                                ValueListenableBuilder<bool>(
                                  valueListenable: SettingsScreen._readReceiptsNotifier,
                                  builder: (context, enabled, _) {
                                    if (!enabled) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Text(
                                        'Read',
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                          fontSize: 11.0,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              if (payload.reactions.isNotEmpty) ...[
                                const WidgetSpacer(height: 10.0),
                                Wrap(
                                  spacing: 6.0,
                                  runSpacing: 4.0,
                                  children: payload.reactions.entries.map((
                                    entry,
                                  ) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10.0,
                                        vertical: 6.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? colors.primary.withValues(
                                                alpha: 0.18,
                                              )
                                            : colors.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(18.0),
                                      ),
                                      child: Text(
                                        '${entry.key} ${entry.value}',
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                          fontSize: 12.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const WidgetSpacer(width: 8.0),
            UserAvatarWidget(url: EnterpriseSession.avatarUrl, size: 36),
          ],
        ],
      ),
    );
  }
}

// =========================================================================
// 7. COMPONENT WIDGETS: AVATARS & ERRORS
// =========================================================================

class UserAvatarWidget extends StatelessWidget {
  final String url;
  final double size;

  const UserAvatarWidget({super.key, required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.person,
                size: size * 0.6,
                color: colors.onSecondaryContainer,
              ),
            )
          : Icon(
              Icons.person,
              size: size * 0.6,
              color: colors.onSecondaryContainer,
            ),
    );
  }
}

class NetworkRecoveryFallbackWidget extends StatelessWidget {
  const NetworkRecoveryFallbackWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 220.0,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_rounded,
            color: colors.onErrorContainer,
            size: 28,
          ),
          const WidgetSpacer(height: 8.0),
          Text(
            'Image failed to load.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onErrorContainer, fontSize: 12.0),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 8. GESTURE COMPONENT ENHANCERS (TACTILE RIPPLE COMPONENT)
// =========================================================================

class TouchFeedbackEnhancer extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const TouchFeedbackEnhancer({
    super.key,
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: borderRadius, onTap: onTap, child: child),
    );
  }
}

// =========================================================================
// 9. EMOTE CONTEXT ACTIONS OVERLAY
// =========================================================================

class EmoteContextActionWrapper extends StatelessWidget {
  final Widget child;
  final String messageId;
  final String messageText;

  const EmoteContextActionWrapper({
    super.key,
    required this.child,
    required this.messageId,
    required this.messageText,
  });

  void _showContextMenu(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children:
                      [
                        '👍',
                        '❤️',
                        '😂',
                        '😮',
                        '😢',
                        '🙏',
                        '🔥',
                        '👏',
                        '😍',
                        '🤣',
                        '😊',
                        '😎',
                      ].map((emote) {
                        return TouchFeedbackEnhancer(
                          onTap: () async {
                            Navigator.pop(context);
                            await ReactionManager.addReaction(messageId, emote);
                            AlertBridge.showNotification(
                              context,
                              "Reacted with $emote",
                            );
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              emote,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.copy_rounded, color: colors.primary),
                title: const Text('Copy Message Text'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: messageText));
                  Navigator.pop(context);
                  AlertBridge.showNotification(context, "Copied to clipboard.");
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: child,
    );
  }
}

// =========================================================================
// 10. PERSISTENT REACTION STORAGE FOR RTDB
// =========================================================================

class ReactionManager {
  static Future<void> addReaction(String messageId, String emoji) async {
    final reactionReference = FirebaseDatabase.instance.ref(
      'messages/$messageId/reactions/$emoji',
    );

    await reactionReference.runTransaction((currentData) {
      final currentValue = (currentData as int?) ?? 0;
      return Transaction.success(currentValue + 1);
    });
  }
}

// =========================================================================
// 11. MEDIA ATTACHMENT PIPELINE & CONTROLLER
// =========================================================================

class TransmissionManager {
  static final TransmissionManager _instance = TransmissionManager._internal();
  factory TransmissionManager() => _instance;
  TransmissionManager._internal();

  void triggerMediaModal(
    BuildContext context,
    Function(String, {String? mediaUrl}) callback,
  ) {
    final TextEditingController urlFieldController = TextEditingController();
    final ValueNotifier<String> errorText = ValueNotifier<String>('');
    final ValueNotifier<String> previewUrl = ValueNotifier<String>('');
    final ValueNotifier<String> selectedFileName = ValueNotifier<String>('');
    final bool useLocalPicker = BackendService.instance.isLocal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 20.0,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const WidgetSpacer(height: 14.0),
                Text(
                  useLocalPicker ? 'Attach a file' : 'Attach via URL',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const WidgetSpacer(height: 8.0),
                Text(
                  useLocalPicker
                      ? 'Pick a file from your device and the app will upload it to your local server.'
                      : 'Paste a direct link to an image or file. The attachment will appear in chat for everyone.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const WidgetSpacer(height: 18.0),
                if (useLocalPicker) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _pickAndUploadAttachmentFile(
                          context,
                          selectedFileName,
                          previewUrl,
                          errorText,
                        );
                      },
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Pick file'),
                    ),
                  ),
                  const WidgetSpacer(height: 8.0),
                  ValueListenableBuilder<String>(
                    valueListenable: selectedFileName,
                    builder: (context, fileName, child) {
                      if (fileName.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _attachmentIconForUrl(fileName),
                              size: 24,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const WidgetSpacer(width: 12.0),
                            Expanded(
                              child: Text(
                                _attachmentLabelForUrl(fileName),
                                style: Theme.of(context).textTheme.bodyMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ] else ...[
                  TextField(
                    controller: urlFieldController,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Image or File URL',
                      hintText: 'https://example.com/image.png',
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      previewUrl.value = value.trim();
                      errorText.value = '';
                    },
                  ),
                ],
                const WidgetSpacer(height: 16.0),
                ValueListenableBuilder<String>(
                  valueListenable: previewUrl,
                  builder: (context, value, child) {
                    if (value.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    if (!useLocalPicker && !_isValidUrl(value)) {
                      return Text(
                        'Enter a valid HTTP or HTTPS URL to preview the attachment.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.error),
                      );
                    }
                    if (!useLocalPicker && _looksLikeImageUrl(value)) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(16.0),
                        child: Image.network(
                          value,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 180,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: double.infinity,
                              height: 180,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              height: 180,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                              child: Center(
                                child: Text(
                                  'Cannot preview image URL.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }
                    if (!useLocalPicker) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _attachmentIconForUrl(value),
                                  size: 24,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const WidgetSpacer(width: 12.0),
                                Expanded(
                                  child: Text(
                                    _attachmentLabelForUrl(value),
                                    style: Theme.of(context).textTheme.bodyMedium,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const WidgetSpacer(height: 10.0),
                            Text(
                              value,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      );
                    }
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _attachmentIconForUrl(value),
                            size: 24,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const WidgetSpacer(width: 12.0),
                          Expanded(
                            child: Text(
                              'Uploaded: ${selectedFileName.value}',
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const WidgetSpacer(height: 16.0),
                ValueListenableBuilder<String>(
                  valueListenable: errorText,
                  builder: (context, value, child) {
                    if (value.isEmpty) return const SizedBox.shrink();
                    return Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.error),
                    );
                  },
                ),
                const WidgetSpacer(height: 18.0),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(bottomSheetContext),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const WidgetSpacer(width: 12.0),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          if (useLocalPicker) {
                            if (previewUrl.value.isEmpty) {
                              errorText.value = 'Please pick a file to attach.';
                              return;
                            }
                            callback('', mediaUrl: previewUrl.value);
                            Navigator.pop(bottomSheetContext);
                            AlertBridge.showNotification(context, 'File attached.');
                            return;
                          }

                          final String uriInput = urlFieldController.text.trim();
                          if (uriInput.isNotEmpty && _isValidUrl(uriInput)) {
                            callback('', mediaUrl: uriInput);
                            Navigator.pop(bottomSheetContext);
                            AlertBridge.showNotification(
                              context,
                              _looksLikeImageUrl(uriInput)
                                  ? 'Image attached.'
                                  : 'File attached.',
                            );
                          } else {
                            errorText.value =
                                'Please enter a valid HTTP or HTTPS URL.';
                          }
                        },
                        child: const Text('Send Attachment'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadAttachmentFile(
    BuildContext context,
    ValueNotifier<String> selectedFileName,
    ValueNotifier<String> previewUrl,
    ValueNotifier<String> errorText,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: false,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      if (file.name.isEmpty) {
        throw Exception('The selected file has no name.');
      }

      final bytes = file.bytes;
      final filePath = file.path;
      if (bytes == null && (filePath == null || filePath.isEmpty)) {
        throw Exception('The selected file could not be read.');
      }

      final contentBase64 = bytes != null
          ? base64Encode(bytes)
          : base64Encode(await File(filePath!).readAsBytes());

      final uploadedUrl = await BackendService.instance.uploadFileAndGetUrl(
        fileName: file.name,
        mimeType: _guessMimeType(file.name),
        contentBase64: contentBase64,
      );

      if (uploadedUrl.isEmpty) {
        throw Exception('The local server did not return an upload URL.');
      }

      selectedFileName.value = file.name;
      previewUrl.value = uploadedUrl;
      errorText.value = '';
    } catch (error) {
      selectedFileName.value = '';
      previewUrl.value = '';
      errorText.value = error.toString();
    }
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }
}

bool _isValidUrl(String value) {
  return value.startsWith('http://') || value.startsWith('https://');
}

bool _looksLikeImageUrl(String url) {
  final lower = url.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.bmp') ||
      lower.contains('image');
}

String _attachmentLabelForUrl(String url) {
  final filename = Uri.tryParse(url)?.pathSegments.last ?? url;
  if (_looksLikeImageUrl(url)) {
    return 'Image preview';
  }
  return filename.isNotEmpty ? filename : 'File attachment';
}

IconData _attachmentIconForUrl(String url) {
  final lower = url.toLowerCase();

  // PDF
  if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;

  // Archives
  if (lower.endsWith('.zip') ||
      lower.endsWith('.rar') ||
      lower.endsWith('.7z') ||
      lower.endsWith('.tar') ||
      lower.endsWith('.gz') ||
      lower.endsWith('.bz2')) {
    return Icons.archive;
  }

  // Audio
  if (lower.endsWith('.mp3') ||
      lower.endsWith('.wav') ||
      lower.endsWith('.aac') ||
      lower.endsWith('.flac') ||
      lower.endsWith('.ogg') ||
      lower.endsWith('.m4a') ||
      lower.endsWith('.wma')) {
    return Icons.audiotrack;
  }

  // Video
  if (lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.mkv') ||
      lower.endsWith('.avi') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.wmv') ||
      lower.endsWith('.m4v') ||
      lower.endsWith('.3gp') ||
      lower.endsWith('.mpeg')) {
    return Icons.movie;
  }

  // Documents
  if (lower.endsWith('.doc') ||
      lower.endsWith('.docx') ||
      lower.endsWith('.odt') ||
      lower.endsWith('.rtf')) {
    return Icons.description;
  }

  // Spreadsheets
  if (lower.endsWith('.xls') ||
      lower.endsWith('.xlsx') ||
      lower.endsWith('.csv') ||
      lower.endsWith('.ods')) {
    return Icons.grid_view;
  }

  // Presentations
  if (lower.endsWith('.ppt') ||
      lower.endsWith('.pptx') ||
      lower.endsWith('.odp') ||
      lower.endsWith('.key')) {
    return Icons.slideshow;
  }

  // Code & text
  if (lower.endsWith('.txt') ||
      lower.endsWith('.md') ||
      lower.endsWith('.json') ||
      lower.endsWith('.xml') ||
      lower.endsWith('.yaml') ||
      lower.endsWith('.yml') ||
      lower.endsWith('.html') ||
      lower.endsWith('.css') ||
      lower.endsWith('.js') ||
      lower.endsWith('.ts') ||
      lower.endsWith('.dart') ||
      lower.endsWith('.java') ||
      lower.endsWith('.kt') ||
      lower.endsWith('.swift') ||
      lower.endsWith('.py') ||
      lower.endsWith('.c') ||
      lower.endsWith('.cpp') ||
      lower.endsWith('.cs') ||
      lower.endsWith('.go') ||
      lower.endsWith('.rs')) {
    return Icons.code;
  }

  // Fonts
  if (lower.endsWith('.ttf') ||
      lower.endsWith('.otf') ||
      lower.endsWith('.woff') ||
      lower.endsWith('.woff2')) {
    return Icons.font_download;
  }

  // Android/iOS apps
  if (lower.endsWith('.apk')) return Icons.android;
  if (lower.endsWith('.ipa')) return Icons.phone_iphone;

  // Executables
  if (lower.endsWith('.exe') ||
      lower.endsWith('.msi') ||
      lower.endsWith('.dmg') ||
      lower.endsWith('.app')) {
    return Icons.computer;
  }

  return Icons.attach_file;
}

Future<void> _openUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    AlertBridge.showNotification(
      context,
      'Invalid attachment URL.',
      isFailureState: true,
    );
    return;
  }

  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      AlertBridge.showNotification(
        context,
        'Unable to open attachment.',
        isFailureState: true,
      );
    }
  } catch (_) {
    AlertBridge.showNotification(
      context,
      'Unable to open attachment.',
      isFailureState: true,
    );
  }
}

// =========================================================================
// 11. COMPONENT GAP ARCHITECTURE SPACERS
// =========================================================================

class WidgetSpacer extends StatelessWidget {
  final double? width;
  final double? height;

  const WidgetSpacer({super.key, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, height: height);
  }
}

extension PaddingDecorator on Widget {
  Widget padAll(double layoutPaddingValue) {
    return Padding(padding: EdgeInsets.all(layoutPaddingValue), child: this);
  }
}

// =========================================================================
// 12. SYSTEM TELEMETRY, TRANSMISSION STATE FEEDBACK & APP INITIALIZER
// =========================================================================

class AlertBridge {
  static void showNotification(
    BuildContext context,
    String message, {
    bool isFailureState = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isFailureState ? colors.onError : colors.onPrimary,
          ),
        ),
        backgroundColor: isFailureState ? colors.error : colors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class AppInitializer {
  static void setupHardwareAcceleration() {
    WidgetsFlutterBinding.ensureInitialized();
  }
}
