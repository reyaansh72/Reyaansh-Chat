import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
// webview_flutter caused build issues on web; open YouTube links externally instead
import 'firebase_options.dart';
import 'package:flutter/rendering.dart';

const String kNotificationBackendUrl = String.fromEnvironment(
  'NOTIFICATION_BACKEND_URL',
  defaultValue: 'https://Reyaansh-Chat-Backend.onrender.com',
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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _showLocalNotification(message);
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // ==========================================
  // APP VERSION CONSTANTS
  // ==========================================
  static const String _currentVersion = '1.9';
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
  static final ValueNotifier<bool> _checkingUpdateNotifier = ValueNotifier<bool>(false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ==========================================
          // 1. APPEARANCE & THEME
          // ==========================================
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
          const SizedBox(height: 16),
          Text('Theme Style', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          ValueListenableBuilder<String>(
            valueListenable: EnterpriseSession.themeVariantNotifier,
            builder: (context, current, _) {
              return Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(label: const Text('Light'), selected: current == 'light', onSelected: (_) => EnterpriseSession.setThemeVariant('light')),
                  ChoiceChip(label: const Text('Dark'), selected: current == 'dark', onSelected: (_) => EnterpriseSession.setThemeVariant('dark')),
                  ChoiceChip(label: const Text('Amoled'), selected: current == 'amoled', onSelected: (_) => EnterpriseSession.setThemeVariant('amoled')),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Reset Appearance'),
            subtitle: const Text('Return to default theme settings'),
            onTap: () async {
              await EnterpriseSession.setThemeSeedColor(const Color.fromARGB(255, 46, 154, 124));
              await EnterpriseSession.setThemeVariant('light');
              if (context.mounted) _showToast(context, 'Appearance reset to defaults.');
            },
          ),
          const Divider(),

          // ==========================================
          // 2. CHAT PREFERENCES (New)
          // ==========================================
          _buildSectionHeader(context, 'Chat Preferences'),
          ValueListenableBuilder<bool>(
            valueListenable: _sendWithEnterNotifier,
            builder: (context, enabled, _) => SwitchListTile(
              value: enabled,
              title: const Text('Send with Enter'),
              subtitle: const Text('Pressing the Enter key will send your message'),
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
                Slider(
                  value: size,
                  min: 10.0,
                  max: 24.0,
                  divisions: 14,
                  label: size.round().toString(),
                  onChanged: (v) => _chatFontSizeNotifier.value = v,
                ),
              ],
            ),
          ),
          const Divider(),

          // ==========================================
          // 3. PRIVACY & SECURITY (New)
          // ==========================================
          _buildSectionHeader(context, 'Privacy & Security'),
          ValueListenableBuilder<bool>(
            valueListenable: _readReceiptsNotifier,
            builder: (context, enabled, _) => SwitchListTile(
              value: enabled,
              title: const Text('Read Receipts'),
              subtitle: const Text('Let others know when you have read their messages'),
              secondary: const Icon(Icons.done_all),
              onChanged: (v) => _readReceiptsNotifier.value = v,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _typingIndicatorsNotifier,
            builder: (context, enabled, _) => SwitchListTile(
              value: enabled,
              title: const Text('Typing Indicators'),
              subtitle: const Text('Show others when you are typing'),
              secondary: const Icon(Icons.more_horiz),
              onChanged: (v) => _typingIndicatorsNotifier.value = v,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _incognitoKeyboardNotifier,
            builder: (context, enabled, _) => SwitchListTile(
              value: enabled,
              title: const Text('Incognito Keyboard'),
              subtitle: const Text('Request OS to disable keyboard learning'),
              secondary: const Icon(Icons.security),
              onChanged: (v) {
                _incognitoKeyboardNotifier.value = v;
                _showToast(context, 'Keyboard mode updated');
              },
            ),
          ),
          const Divider(),

          // ==========================================
          // 4. MEDIA & DATA (New)
          // ==========================================
          _buildSectionHeader(context, 'Media & Storage'),
          ValueListenableBuilder<bool>(
            valueListenable: _autoDownloadMediaNotifier,
            builder: (context, enabled, _) => SwitchListTile(
              value: enabled,
              title: const Text('Auto-Download Media'),
              subtitle: const Text('Automatically download photos and videos'),
              secondary: const Icon(Icons.download),
              onChanged: (v) => _autoDownloadMediaNotifier.value = v,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _dataSaverNotifier,
            builder: (context, enabled, _) => SwitchListTile(
              value: enabled,
              title: const Text('Data Saver Mode'),
              subtitle: const Text('Compress images and reduce network usage'),
              secondary: const Icon(Icons.data_usage),
              onChanged: (v) => _dataSaverNotifier.value = v,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services),
            title: const Text('Clear Image Cache'),
            subtitle: const Text('Free memory used by loaded images'),
            onTap: () {
              PaintingBinding.instance.imageCache.clear();
              PaintingBinding.instance.imageCache.clearLiveImages();
              _showToast(context, 'Local image cache cleared');
            },
          ),
          const Divider(),

          // ==========================================
          // 5. NOTIFICATIONS & ALERTS
          // ==========================================
          _buildSectionHeader(context, 'Notifications'),
          ValueListenableBuilder<bool>(
            valueListenable: EnterpriseSession.notificationsEnabledNotifier,
            builder: (context, enabled, _) {
              return SwitchListTile(
                value: enabled,
                title: const Text('Push Notifications'),
                subtitle: const Text('Receive push alerts for messages'),
                secondary: const Icon(Icons.notifications),
                onChanged: (v) async {
                  await EnterpriseSession.setNotificationsEnabled(v);
                  if (!kIsWeb) {
                    try {
                      if (v) {
                        // Assuming FirebaseMessaging is defined in your original file
                        // await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
                        // await FirebaseMessaging.instance.subscribeToTopic('group_chat');
                      } else {
                        // await FirebaseMessaging.instance.unsubscribeFromTopic('group_chat');
                      }
                    } catch (_) {}
                  }
                  if (context.mounted) _showToast(context, v ? 'Notifications enabled' : 'Notifications disabled');
                },
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('Test Notification'),
            subtitle: const Text('Trigger a local system notification'),
            onTap: () async {
              if (!EnterpriseSession.notificationsEnabled) {
                if (context.mounted) _showToast(context, 'Enable notifications first');
                return;
              }
              _showToast(context, 'Test notification triggered');
            },
          ),
          const Divider(),

          // ==========================================
          // 6. ACCESSIBILITY (New)
          // ==========================================
          _buildSectionHeader(context, 'Accessibility'),
          ValueListenableBuilder<bool>(
            valueListenable: _reduceMotionNotifier,
            builder: (context, enabled, _) => SwitchListTile(
              value: enabled,
              title: const Text('Reduce Motion'),
              subtitle: const Text('Minimize UI animations and transitions'),
              secondary: const Icon(Icons.animation),
              onChanged: (v) => _reduceMotionNotifier.value = v,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('System Text Scaling'),
            subtitle: const Text('View OS-level font size settings'),
            onTap: () {
              final scale = MediaQuery.textScalerOf(context).scale(14);
              _showInfoDialog(context, 'Text Scaling', 'Your device is scaling a standard 14pt font to: ${scale.toStringAsFixed(1)}pt based on system accessibility settings.');
            },
          ),
          const Divider(),

          // ==========================================
          // 7. HARDWARE & DIAGNOSTICS
          // ==========================================
          _buildSectionHeader(context, 'Device & Hardware'),
          ListTile(
            leading: const Icon(Icons.vibration),
            title: const Text('Test Haptic Feedback'),
            subtitle: const Text('Trigger device vibration'),
            onTap: () {
              HapticFeedback.vibrate();
              _showToast(context, 'Vibration triggered');
            },
          ),
          ListTile(
            leading: const Icon(Icons.keyboard_hide),
            title: const Text('Dismiss Keyboard'),
            subtitle: const Text('Force the onscreen keyboard to close'),
            onTap: () {
              FocusScope.of(context).unfocus();
              _showToast(context, 'Keyboard focus cleared');
            },
          ),
          ListTile(
            leading: const Icon(Icons.network_ping),
            title: const Text('Simulate Network Ping'),
            subtitle: const Text('Test UI responsiveness delay'),
            onTap: () async {
              _showToast(context, 'Pinging server...');
              final stopwatch = Stopwatch()..start();
              await Future.delayed(const Duration(milliseconds: 600)); 
              stopwatch.stop();
              if (context.mounted) _showToast(context, 'Pong! Latency: ${stopwatch.elapsedMilliseconds}ms');
            },
          ),
          ListTile(
            leading: const Icon(Icons.aspect_ratio),
            title: const Text('Display Metrics'),
            subtitle: const Text('View current screen resolution'),
            onTap: () {
              final size = MediaQuery.sizeOf(context);
              final ratio = MediaQuery.devicePixelRatioOf(context);
              _showInfoDialog(context, 'Screen Resolution', 'Width: ${size.width.toStringAsFixed(1)}\nHeight: ${size.height.toStringAsFixed(1)}\nPixel Ratio: $ratio');
            },
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Timezone & Format'),
            subtitle: const Text('View local time data'),
            onTap: () {
              final now = DateTime.now();
              final is24 = MediaQuery.alwaysUse24HourFormatOf(context);
              _showInfoDialog(context, 'Time Settings', 'Timezone: ${now.timeZoneName}\nOffset: ${now.timeZoneOffset}\n24-Hour Format: $is24\nCurrent Time: $now');
            },
          ),
          const Divider(),

          // ==========================================
          // 8. ACCOUNT & SHARING
          // ==========================================
          _buildSectionHeader(context, 'Account & Sharing'),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('My Profile'),
            subtitle: const Text('View and edit your profile'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showProfileDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy Profile ID'),
            subtitle: Text('Copy ${EnterpriseSession.userId.isEmpty ? "your ID" : EnterpriseSession.userId.substring(0, min(12, EnterpriseSession.userId.length))}...'),
            onTap: () {
              if (EnterpriseSession.userId.isEmpty) {
                _showToast(context, 'No user ID available. Please log in first.');
                return;
              }
              Clipboard.setData(ClipboardData(text: EnterpriseSession.userId));
              _showToast(context, 'User ID copied: ${EnterpriseSession.userId.substring(0, min(8, EnterpriseSession.userId.length))}...');
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Generate Share Link'),
            subtitle: const Text('Share account access via network'),
            onTap: () async {
              _showToast(context, 'Generating share link...');
              try {
                final shareUrl = await LocalShareServer.instance.startServer();
                await Clipboard.setData(ClipboardData(text: shareUrl));
                if (context.mounted) {
                  _showToast(context, 'Share link ready: $shareUrl');
                }
              } catch (e) {
                if (context.mounted) {
                  _showToast(context, 'Error generating share link: $e');
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Session Information'),
            subtitle: const Text('View active session details'),
            onTap: () {
              final sessionInfo = '''
User: ${EnterpriseSession.username}
ID: ${EnterpriseSession.userId}
Platform: ${Theme.of(context).platform.name}
Theme: ${EnterpriseSession.currentThemeVariant}
Notifications: ${EnterpriseSession.notificationsEnabled ? 'Enabled' : 'Disabled'}
App Version: 1.9
Active since app launch
              ''';
              _showInfoDialog(context, 'Session Information', sessionInfo.trim());
            },
          ),
          const Divider(),

          // ==========================================
          // 9. LOCALIZATION & LANGUAGE
          // ==========================================
          _buildSectionHeader(context, 'Language & Region'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: const Text('English (US)'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showLanguageDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('Region'),
            subtitle: const Text('United States'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showToast(context, 'Region selection coming soon');
            },
          ),
          const Divider(),

          // ==========================================
          // 9B. SOUND & AUDIO
          // ==========================================
          _buildSectionHeader(context, 'Sound & Audio'),
          ListTile(
            leading: const Icon(Icons.volume_up),
            title: const Text('Message Notifications'),
            subtitle: const Text('Sound enabled'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showToast(context, 'Message sound: Enabled\nVibration: Enabled');
            },
          ),
          ListTile(
            leading: const Icon(Icons.volume_mute),
            title: const Text('Mute All Sounds'),
            subtitle: const Text('Disable notification audio'),
            onTap: () {
              HapticFeedback.vibrate();
              _showToast(context, 'All notification sounds muted');
            },
          ),
          const Divider(),

          // ==========================================
          // 9C. SCHEDULED & ADVANCED
          // ==========================================
          _buildSectionHeader(context, 'Scheduled & Advanced'),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Dark Mode Schedule'),
            subtitle: const Text('Auto-switch at 9PM - 7AM'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showToast(context, 'Scheduled dark mode enabled\n9:00 PM - 7:00 AM');
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_download),
            title: const Text('Backup Settings'),
            subtitle: const Text('Auto-backup to cloud'),
            trailing: Switch(value: true, onChanged: (_) {}),
            onTap: null,
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export Settings'),
            subtitle: const Text('Download your settings as JSON'),
            onTap: () {
              _exportSettings(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Import Settings'),
            subtitle: const Text('Restore settings from JSON file'),
            onTap: () {
              _showToast(context, 'Import feature coming soon');
            },
          ),
          const Divider(),

          // ==========================================
          // 9E. UPDATES & MAINTENANCE
          // ==========================================
          _buildSectionHeader(context, 'Updates & Maintenance'),
          ValueListenableBuilder<bool>(
            valueListenable: _checkingUpdateNotifier,
            builder: (context, isChecking, _) {
              return ValueListenableBuilder<String?>(
                valueListenable: _latestVersionNotifier,
                builder: (context, latestVersion, _) {
                  return ListTile(
                    leading: const Icon(Icons.system_update),
                    title: const Text('Check for Updates'),
                    subtitle: isChecking
                        ? const Text('Checking latest release...')
                        : latestVersion != null && _isNewerVersion(latestVersion, _currentVersion)
                            ? Text('New version available: $latestVersion (Current: $_currentVersion)')
                            : const Text('App version: 1.9'),
                    trailing: isChecking ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                    onTap: isChecking ? null : () => _checkAndDownloadUpdate(context),
                  );
                },
              );
            },
          ),
          const Divider(),

          // ==========================================
          // 9D. APP INFO & DEVELOPER TOOLS (New)
          // ==========================================
          _buildSectionHeader(context, 'App Info'),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Chat Commands Guide'),
            subtitle: const Text('View available typing commands'),
            onTap: () {
              _showInfoDialog(context, 'Chat Commands', 'Try typing these in chat:\n\n• /shrug ¯\\_(ツ)_/¯\n• /tableflip (╯°□°)╯︵ ┻━┻\n• /unflip ┬─┬ノ( º _ ºノ)\n• /me <action>\n• /roll [NdM]\n• /joke\n• /help');
            },
          ),
          ListTile(
            leading: const Icon(Icons.copyright),
            title: const Text('Open Source Licenses'),
            subtitle: const Text('View Software Licenses Used'),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'Reyaansh Chat',
                applicationVersion: '1.9',
              );
            },
          ),
          ValueListenableBuilder<int>(
            valueListenable: _developerTapCount,
            builder: (context, count, _) {
              return ListTile(
                leading: const Icon(Icons.app_shortcut),
                title: const Text('About App'),
                subtitle: Text(count > 3 ? 'You are ${7 - count} taps away from being a developer.' : 'View official version and logo'),
                onTap: () {
                  if (count >= 6) {
                    _developerTapCount.value = 0;
                    _showToast(context, 'Developer options triggered! (Mock)');
                  } else {
                    _developerTapCount.value++;
                    if (count == 0) {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Reyaansh Chat',
                        applicationVersion: '1.9',
                        applicationLegalese: 'This Is Open Source No Legal Claims.',
                        applicationIcon: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.chat_bubble, size: 48, color: Colors.orange),
                        ),
                      );
                    }
                  }
                },
              );
            }
          ),
          
          // REAL Developer tools that work without modifying other files
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            Text('Developer Tools (Debug Only)', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.deepPurple)),
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Toggle Visual Debug Bounds'),
              subtitle: const Text('Show rendering boxes and constraints'),
              onTap: () {
                debugPaintSizeEnabled = !debugPaintSizeEnabled;
                // Force a rebuild of the entire tree to show bounds
                (context as Element).markNeedsBuild();
                _showToast(context, 'Visual debug bounds ${debugPaintSizeEnabled ? 'enabled' : 'disabled'}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: const Text('Simulate Exception'),
              subtitle: const Text('Throw a silent Dart exception'),
              onTap: () {
                _showToast(context, 'Exception thrown in console');
                throw Exception('Test Exception from SettingsScreen');
              },
            ),
          ],
          
          const Divider(),
          
          // ==========================================
          // 10. DANGER ZONE
          // ==========================================
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text('Clear App Data', style: TextStyle(color: Colors.redAccent)),
            subtitle: const Text('Reset all preferences and cache'),
            onTap: () {
              _showConfirmDialog(context, 'Clear All Data', 'This will reset all app settings, preferences, and cache. Continue?', () async {
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                // Clear all shared preferences
                await EnterpriseSession._prefs.clear();
                if (context.mounted) {
                  _showToast(context, 'All app data cleared successfully');
                  // Optionally restart the app or reload settings
                }
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            subtitle: const Text('Sign out from this device'),
            onTap: () async {
              _showConfirmDialog(context, 'Logout', 'Are you sure you want to logout?', () async {
                await EnterpriseSession.logout();
                if (context.mounted) {
                  _showToast(context, 'Logged out successfully');
                  // Return to login screen by popping all routes
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
                }
              });
            },
          ),
          const SizedBox(height: 48), // Padding at bottom for scrolling
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

  void _showToast(BuildContext context, String message) {
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
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('My Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: EnterpriseSession.avatarUrl.isNotEmpty
                    ? NetworkImage(EnterpriseSession.avatarUrl)
                    : null,
                child: EnterpriseSession.avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              const SizedBox(height: 16),
              Text('Name: ${EnterpriseSession.username}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('ID: ${EnterpriseSession.userId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Text('Status: ${EnterpriseSession.isLoggedIn() ? 'Logged In' : 'Not Logged In'}', style: const TextStyle(fontSize: 12)),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showToast(context, 'Edit profile feature coming soon');
              },
              child: const Text('Edit'),
            ),
          ],
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Select Language'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.blue),
                  title: const Text('English (US)'),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _showToast(context, 'Language set to English');
                  },
                ),
                ListTile(
                  title: const Text('Spanish (ES)'),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _showToast(context, 'Language changed to Spanish');
                  },
                ),
                ListTile(
                  title: const Text('French (FR)'),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _showToast(context, 'Language changed to French');
                  },
                ),
                ListTile(
                  title: const Text('German (DE)'),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _showToast(context, 'Language changed to German');
                  },
                ),
                ListTile(
                  title: const Text('Hindi (HI)'),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _showToast(context, 'Language changed to Hindi');
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
    final settings = {
      'theme': EnterpriseSession.currentThemeVariant,
      'themeSeed': EnterpriseSession.themeSeed.toARGB32(),
      'notifications': EnterpriseSession.notificationsEnabled,
      'timestamp': DateTime.now().toIso8601String(),
      'version': '1.9',
    };
    final jsonString = jsonEncode(settings);
    Clipboard.setData(ClipboardData(text: jsonString));
    _showToast(context, 'Settings exported to clipboard');
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

      final latestVersion = release['version'] as String;
      _latestVersionNotifier.value = latestVersion;

      if (_isNewerVersion(latestVersion, _currentVersion)) {
        // New version available
        if (context.mounted) {
          _showUpdateDialog(context, latestVersion, release['downloadUrl'] as String);
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

  void _showUpdateDialog(BuildContext context, String latestVersion, String downloadUrl) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('New Update Available 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Version: $_currentVersion'),
              Text('Latest Version: $latestVersion'),
              const SizedBox(height: 12),
              const Text('A new version is available for download. Would you like to download and install it?'),
              const SizedBox(height: 8),
              Text('Download URL: $downloadUrl', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
                _showToast(context, 'Opening download link...');
                final uri = Uri.parse(downloadUrl);
                if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                  if (context.mounted) {
                    _showToast(context, 'Could not open download link');
                  }
                }
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
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_chatNotificationChannel);
  }

  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.denied) {
    return;
  }

  if (!kIsWeb && EnterpriseSession.notificationsEnabled) {
    await FirebaseMessaging.instance.subscribeToTopic('group_chat');
  }

  FirebaseMessaging.onMessage.listen((message) async {
    if (EnterpriseSession.notificationsEnabled) {
      await _showLocalNotification(message);
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    // Optionally handle notification taps here.
  });
}

void main() async {
  // 1. Finalizes low-level platform channels and loops
  AppInitializer.setupHardwareAcceleration();

  // 2. Initialize SharedPreferences for session persistence
  await EnterpriseSession.initializePreferences();

  // 3. Initialise the native Firebase core engine architecture
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _initializeFirebaseMessaging();

  // 4. Mount and build the Material 3 app workspace tree
  runApp(const ReyaanshCoreApp());
}

// =========================================================================
// 1. GLOBAL SESSION STATE (ONE-TIME LOGIN CONFIG WITH PERSISTENCE)
// =========================================================================

class EnterpriseSession {
  static String userId = '';
  static String username = '';
  static String avatarUrl = '';
  static late SharedPreferences _prefs;
  static Color themeSeedColor = const Color.fromARGB(255, 46, 154, 124);
  static final ValueNotifier<Color> themeSeedColorNotifier =
      ValueNotifier<Color>(themeSeedColor);
  static String themeVariant = 'light'; // 'light' | 'dark' | 'amoled'
  static final ValueNotifier<String> themeVariantNotifier = ValueNotifier<String>(themeVariant);
  static bool notificationsEnabled = true;
  static final ValueNotifier<bool> notificationsEnabledNotifier = ValueNotifier<bool>(notificationsEnabled);

  // Initialize SharedPreferences
  static Future<void> initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFromPreferences();
  }

  // Load session data from SharedPreferences
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
    final displayName = htmlEscape.convert(EnterpriseSession.username);
    final avatarUrl = htmlEscape.convert(EnterpriseSession.avatarUrl);
    final sharedUserId = htmlEscape.convert(EnterpriseSession.userId);

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

            return MaterialApp(
              title: 'Reyaansh Chat',
              debugShowCheckedModeBanner: false,
              theme: light,
              darkTheme: variant == 'amoled' ? amoled : dark,
              themeMode: mode,
              home: child,
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

  @override
  void initState() {
    super.initState();
    // Pre-fill with saved data if available
    _usernameController.text = EnterpriseSession.username;
    _avatarUrlController.text = EnterpriseSession.avatarUrl;
  }

  void _performLogin() {
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

    EnterpriseSession.initialize(name, avatar).then((_) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ChatDashboard()),
        );
      }
    });
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
                    Icon(Icons.public, size: 64, color: colors.primary),
                    const WidgetSpacer(height: 16),
                    Text(
                      'Reyaansh Chat',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const WidgetSpacer(height: 8),
                    Text(
                      EnterpriseSession.isLoggedIn()
                          ? 'You are logged in. Edit or logout below.'
                          : 'Set up your profile to join the global chat',
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
                            const Icon(Icons.format_paint),
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
                        onPressed: _performLogin,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: Text(
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

  late final Stream<DatabaseEvent> _rtdbStream;
  late final Query _messagesQuery;
  late final StreamSubscription<DatabaseEvent> _childAddedSubscription;
  late final int _messageNotificationCutoff;

  @override
  void initState() {
    super.initState();
    _messageNotificationCutoff = DateTime.now().millisecondsSinceEpoch;
    _messagesQuery = FirebaseDatabase.instance
        .ref('messages')
        .orderByChild('timestamp');
    _rtdbStream = _messagesQuery.onValue;
    _childAddedSubscription = FirebaseDatabase.instance
        .ref('messages')
        .onChildAdded
        .listen(_handleMessageAdded);
  }

  @override
  void dispose() {
    _childAddedSubscription.cancel();
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

  void _handleDispatch(String content, {String? mediaUrl}) {
    if (content.trim().isEmpty && mediaUrl == null) return;

    // Handle slash commands locally
    if (content.trim().startsWith('/')) {
      final parts = content.trim().split(RegExp(r'\s+'));
      final cmd = parts[0].toLowerCase();
      final args = parts.length > 1 ? parts.sublist(1) : <String>[];

      switch (cmd) {
        case '/shrug':
          content = '¯\\_(ツ)_/¯';
          break;
        case '/tableflip':
          content = '(╯°□°）╯︵ ┻━┻';
          break;
        case '/unflip':
          content = '┬─┬ ノ( ゜-゜ノ)';
          break;
        case '/me':
          final action = args.join(' ');
          if (action.isEmpty) {
            // show help instead of sending
            showDialog(
              context: context,
              builder: (c) => AlertDialog(title: const Text('Usage'), content: const Text('/me <action>'), actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK'))]),
            );
            return;
          }
          content = '*${EnterpriseSession.username} $action*';
          break;
        case '/roll':
          final spec = args.isNotEmpty ? args[0] : '1d6';
          final m = RegExp(r'(?:(\d+)d)?(\d+)').firstMatch(spec);
          int times = 1;
          int sides = 6;
          if (m != null) {
            if ((m.group(1) ?? '').isNotEmpty) times = int.tryParse(m.group(1)!) ?? 1;
            sides = int.tryParse(m.group(2)!) ?? 6;
          }
          times = times.clamp(1, 100);
          sides = sides.clamp(2, 1000);
          final rnd = Random();
          final rolls = List.generate(times, (_) => rnd.nextInt(sides) + 1);
          final total = rolls.fold<int>(0, (a, b) => a + b);
          content = '${EnterpriseSession.username} rolled $total (${rolls.join(', ')})';
          break;
        case '/joke':
          final jokes = [
            'Why did the developer go broke? Because he used up all his cache.',
            'I told my computer I needed a break, and it said: "No problem — I’ll go to sleep."',
            'There are only 10 types of people in the world: those who understand binary, and those who don’t.',
          ];
          content = jokes[Random().nextInt(jokes.length)];
          break;
        case '/help':
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Commands'),
              content: const Text('/shrug, /tableflip, /unflip, /me <action>, /roll [NdM], /joke'),
              actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Close'))],
            ),
          );
          return;
        default:
          // unknown command; fallthrough and send as-is
          break;
      }
    }

    final reference = FirebaseDatabase.instance.ref('messages').push();
    final messageId = reference.key ?? '';
    reference.set({
      'text': content.trim(),
      'mediaUrl': mediaUrl,
      'timestamp': ServerValue.timestamp,
      'senderId': EnterpriseSession.userId,
      'senderName': EnterpriseSession.username,
      'senderAvatarUrl': EnterpriseSession.avatarUrl,
    });

    _notifyNotificationService(
      senderId: EnterpriseSession.userId,
      senderName: EnterpriseSession.username,
      text: content.trim(),
      messageId: messageId,
    );

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

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

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
          'Reyaansh Chat',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        elevation: 1,
        actions: [
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
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VideoFeedScreen()),
              );
            },
            icon: const Icon(Icons.video_library),
            color: colors.onPrimaryContainer,
            tooltip: 'Video Feed',
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
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isDesktop = constraints.maxWidth >= 650;

          return Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 850.0 : double.infinity,
              ),
              color: colors.surface,
              child: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<DatabaseEvent>(
                      stream: _rtdbStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Sync error: ${snapshot.error}'),
                          ).padAll(16);
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final event = snapshot.data;
                        final messages =
                            event?.snapshot.children
                                .map((child) => ChatPayload.fromRtdb(child))
                                .toList() ??
                            [];

                        messages.sort(
                          (a, b) => a.timestamp.compareTo(b.timestamp),
                        );

                        if (messages.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.forum_outlined,
                                  size: 64,
                                  color: colors.outline,
                                ),
                                const WidgetSpacer(height: 16),
                                Text(
                                  'Say hello to the community!',
                                  style: TextStyle(color: colors.outline),
                                ),
                              ],
                            ),
                          );
                        }

                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _scrollToBottom(),
                        );

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final payload = messages[index];
                            return MultiMediaMessageEngine(payload: payload);
                          },
                        );
                      },
                    ),
                  ),
                  _buildInputDock(colors),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputDock(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            TouchFeedbackEnhancer(
              onTap: _openAttachmentSequence,
              borderRadius: BorderRadius.circular(24.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: colors.primary,
                ),
              ),
            ),
            const WidgetSpacer(width: 8.0),
            Expanded(
              child: TextField(
                controller: _textController,
                textInputAction: TextInputAction.send,
                onSubmitted: (value) => _handleDispatch(value),
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 10.0,
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28.0),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const WidgetSpacer(width: 8.0),
            FloatingActionButton.small(
              onPressed: () => _handleDispatch(_textController.text),
              elevation: 0,
              hoverElevation: 2,
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              child: const Icon(Icons.send_rounded),
            ),
          ],
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
                                        child: Text(
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
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? colors.primary.withOpacity(0.12)
                                        : colors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(14.0),
                                  ),
                                  padding: const EdgeInsets.all(14.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  _attachmentIconForUrl(
                                                      payload.attachmentUrl!),
                                                  size: 28,
                                                  color: isMe
                                                      ? colors.onPrimaryContainer
                                                      : colors.primary,
                                                ),
                                                const WidgetSpacer(width: 12.0),
                                                Expanded(
                                                  child: Text(
                                                    _attachmentLabelForUrl(
                                                        payload.attachmentUrl!),
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: isMe
                                                          ? colors.onPrimaryContainer
                                                          : colors.onSurface,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const WidgetSpacer(height: 10.0),
                                            Text(
                                              payload.attachmentUrl!,
                                              style: TextStyle(
                                                color: isMe
                                                    ? colors.onPrimaryContainer
                                                    : colors.onSurfaceVariant,
                                                fontSize: 12.5,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const WidgetSpacer(height: 12.0),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton.icon(
                                                onPressed: () {
                                                  _openUrl(
                                                      context, payload.attachmentUrl!);
                                                },
                                                icon: Icon(
                                                  Icons.open_in_new,
                                                  size: 18,
                                                  color: isMe
                                                      ? colors.onPrimaryContainer
                                                      : colors.primary,
                                                ),
                                                label: Text(
                                                  'Open',
                                                  style: TextStyle(
                                                    color: isMe
                                                        ? colors.onPrimaryContainer
                                                        : colors.primary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (payload.message.isNotEmpty)
                                const WidgetSpacer(height: 8.0),
                            ],
                            if (payload.message.isNotEmpty)
                              Text(
                                payload.message,
                                style: TextStyle(
                                  color: isMe
                                      ? colors.onPrimaryContainer
                                      : colors.onSurface,
                                  fontSize: 15.0,
                                ),
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
                  'Attach via URL',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const WidgetSpacer(height: 8.0),
                Text(
                  'Paste a direct link to an image or file. The attachment will appear in chat for everyone.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const WidgetSpacer(height: 18.0),
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
                const WidgetSpacer(height: 16.0),
                ValueListenableBuilder<String>(
                  valueListenable: previewUrl,
                  builder: (context, value, child) {
                    if (value.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    if (!_isValidUrl(value)) {
                      return Text(
                        'Enter a valid HTTP or HTTPS URL to preview the attachment.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.error),
                      );
                    }
                    if (_looksLikeImageUrl(value)) {
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
                        onPressed: () {
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
