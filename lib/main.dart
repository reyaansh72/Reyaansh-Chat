import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

void main() async {
  // 1. Finalizes low-level platform channels and loops
  AppInitializer.setupHardwareAcceleration();

  // 2. Initialize SharedPreferences for session persistence
  await EnterpriseSession.initializePreferences();

  // 3. Initialise the native Firebase core engine architecture
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 4. Mount and build the Material 3 app workspace tree
  runApp(const ReyaanshCoreApp());
}

// =========================================================================
// 1. GLOBAL SESSION STATE (ONE-TIME LOGIN CONFIG WITH PERSISTENCE)
// =========================================================================

class Contact {
  final String username;
  final String userId;
  final String avatarUrl;

  Contact({
    required this.username,
    required this.userId,
    required this.avatarUrl,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      username: json['username'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'username': username, 'userId': userId, 'avatarUrl': avatarUrl};
  }
}

class ContactManager {
  static final ContactManager _instance = ContactManager._internal();
  factory ContactManager() => _instance;
  ContactManager._internal();

  late SharedPreferences _prefs;
  final ValueNotifier<List<Contact>> contactsNotifier =
      ValueNotifier<List<Contact>>([]);

  Future<void> initialize(SharedPreferences prefs) async {
    _prefs = prefs;
    await _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contactsJson = _prefs.getStringList('contacts') ?? [];
    final contacts = contactsJson
        .map(
          (json) => Contact.fromJson(jsonDecode(json) as Map<String, dynamic>),
        )
        .toList();
    contactsNotifier.value = contacts;
  }

  Future<void> addContact(Contact contact) async {
    final contacts = List<Contact>.from(contactsNotifier.value);

    // Avoid duplicate contacts
    if (!contacts.any((c) => c.userId == contact.userId)) {
      contacts.add(contact);
      contactsNotifier.value = contacts;

      final contactsJson = contacts.map((c) => jsonEncode(c.toJson())).toList();
      await _prefs.setStringList('contacts', contactsJson);
    }
  }

  Future<void> removeContact(String userId) async {
    final contacts = List<Contact>.from(contactsNotifier.value);
    contacts.removeWhere((c) => c.userId == userId);
    contactsNotifier.value = contacts;

    final contactsJson = contacts.map((c) => jsonEncode(c.toJson())).toList();
    await _prefs.setStringList('contacts', contactsJson);
  }

  List<Contact> getContacts() => contactsNotifier.value;
}

class EnterpriseSession {
  static String userId = '';
  static String username = '';
  static String avatarUrl = '';
  static late SharedPreferences _prefs;
  static Color themeSeedColor = const Color.fromARGB(255, 46, 154, 124);
  static final ValueNotifier<Color> themeSeedColorNotifier =
      ValueNotifier<Color>(themeSeedColor);

  // Initialize SharedPreferences
  static Future<void> initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
    await ContactManager().initialize(_prefs);
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
    themeSeedColorNotifier.value = themeSeedColor;
  }

  static Color get themeSeed => themeSeedColorNotifier.value;

  static Future<void> setThemeSeedColor(Color color) async {
    themeSeedColor = color;
    themeSeedColorNotifier.value = color;
    await _prefs.setInt('themeSeedColor', color.toARGB32());
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
        return MaterialApp(
          title: 'Reyaansh Chat',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: Brightness.light,
            ).copyWith(surfaceContainerHigh: const Color(0xFFF4F6E7)),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.normal,
              ),
              bodyMedium: TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.normal,
              ),
              labelSmall: TextStyle(fontSize: 11.0, color: Colors.grey),
            ),
          ),
          home: child,
        );
      },
      child: EnterpriseSession.isLoggedIn()
          ? const ChatDashboard()
          : const LoginScreen(),
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
                      onTap: () => ThemeColorPicker.open(context),
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

  Contact? _selectedContact;
  bool _sidebarExpanded = true;

  late final Stream<DatabaseEvent> _rtdbStream;
  late final Query _messagesQuery;

  @override
  void initState() {
    super.initState();
    _setupMessagesQuery();
  }

  void _setupMessagesQuery() {
    if (_selectedContact != null) {
      final contactPath = 'messages/${_selectedContact!.userId}';
      _messagesQuery = FirebaseDatabase.instance
          .ref(contactPath)
          .orderByChild('timestamp');
      _rtdbStream = _messagesQuery.onValue;
    }
  }

  void _selectContact(Contact contact) {
    setState(() {
      _selectedContact = contact;
      _setupMessagesQuery();
    });
  }

  void _showAddContactDialog() {
    final TextEditingController usernameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the username to add as a contact.'),
              const WidgetSpacer(height: 16),
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final username = usernameController.text.trim();
                if (username.isNotEmpty) {
                  // In a real app, you'd search Firebase for this user
                  // For now, we'll create a contact with the username
                  final newContact = Contact(
                    username: username,
                    userId:
                        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
                    avatarUrl: '',
                  );

                  await ContactManager().addContact(newContact);
                  if (!mounted) return;
                  Navigator.pop(context);
                  AlertBridge.showNotification(
                    context,
                    'Contact "$username" added successfully.',
                  );
                  _selectContact(newContact);
                } else {
                  AlertBridge.showNotification(
                    context,
                    'Please enter a username.',
                    isFailureState: true,
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
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
    if (_selectedContact == null) {
      AlertBridge.showNotification(
        context,
        'Please select a contact to message.',
        isFailureState: true,
      );
      return;
    }

    final contactPath = 'messages/${_selectedContact!.userId}';
    final reference = FirebaseDatabase.instance.ref(contactPath).push();
    reference.set({
      'text': content.trim(),
      'mediaUrl': mediaUrl,
      'timestamp': ServerValue.timestamp,
      'senderId': EnterpriseSession.userId,
      'senderName': EnterpriseSession.username,
      'senderAvatarUrl': EnterpriseSession.avatarUrl,
    });

    _textController.clear();
    Future.delayed(const Duration(milliseconds: 200), _scrollToBottom);
  }

  void _openAttachmentSequence() {
    TransmissionManager().triggerMediaModal(context, _handleDispatch);
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
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(colors, handleLogout),
          // Chat area
          Expanded(
            child: Column(
              children: [
                // Header with selected contact
                if (_selectedContact != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      border: Border(
                        bottom: BorderSide(
                          color: colors.outlineVariant,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        UserAvatarWidget(
                          url: _selectedContact!.avatarUrl,
                          size: 40,
                        ),
                        const WidgetSpacer(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedContact!.username,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                            Text(
                              'Direct Message',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onPrimaryContainer.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      border: Border(
                        bottom: BorderSide(
                          color: colors.outlineVariant,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Select a contact to start messaging',
                        style: TextStyle(
                          color: colors.onPrimaryContainer,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                // Messages list
                if (_selectedContact != null)
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
                                  'Start a conversation!',
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
                  )
                else
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_add_outlined,
                            size: 64,
                            color: colors.outline,
                          ),
                          const WidgetSpacer(height: 16),
                          Text(
                            'No contact selected',
                            style: TextStyle(color: colors.outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Input dock
                if (_selectedContact != null) _buildInputDock(colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(ColorScheme colors, VoidCallback handleLogout) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _sidebarExpanded ? 280 : 80,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          right: BorderSide(color: colors.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Header with collapse button
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              border: Border(
                bottom: BorderSide(color: colors.outlineVariant, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                if (_sidebarExpanded)
                  Expanded(
                    child: Text(
                      'Messages',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    _sidebarExpanded ? Icons.chevron_left : Icons.chevron_right,
                  ),
                  onPressed: () {
                    setState(() {
                      _sidebarExpanded = !_sidebarExpanded;
                    });
                  },
                  iconSize: 24,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Add Contact Button
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox(
              width: double.infinity,
              child: _sidebarExpanded
                  ? FilledButton.icon(
                      onPressed: _showAddContactDialog,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Contact'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: _showAddContactDialog,
                      icon: const Icon(Icons.person_add),
                      tooltip: 'Add Contact',
                    ),
            ),
          ),
          // Contacts List
          Expanded(
            child: ValueListenableBuilder<List<Contact>>(
              valueListenable: ContactManager().contactsNotifier,
              builder: (context, contacts, _) {
                if (contacts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 40,
                            color: colors.outline,
                          ),
                          if (_sidebarExpanded) ...[
                            const WidgetSpacer(height: 8),
                            Text(
                              'No contacts yet',
                              style: TextStyle(color: colors.outline),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final isSelected =
                        _selectedContact?.userId == contact.userId;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12.0),
                          onTap: () => _selectContact(contact),
                          onLongPress: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Remove Contact'),
                                content: Text(
                                  'Remove ${contact.username} from contacts?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () async {
                                      await ContactManager().removeContact(
                                        contact.userId,
                                      );
                                      if (!mounted) return;
                                      Navigator.pop(context);
                                      AlertBridge.showNotification(
                                        context,
                                        'Contact removed.',
                                      );
                                    },
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Row(
                              children: [
                                UserAvatarWidget(
                                  url: contact.avatarUrl,
                                  size: 40,
                                ),
                                if (_sidebarExpanded) ...[
                                  const WidgetSpacer(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          contact.username,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: isSelected
                                                ? colors.onPrimaryContainer
                                                : colors.onSurface,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Direct message',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Bottom action buttons
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colors.outlineVariant, width: 0.5),
              ),
            ),
            child: Column(
              children: [
                if (_sidebarExpanded) ...[
                  SizedBox(
                    width: double.infinity,
                    child: Tooltip(
                      message: 'Theme Color',
                      child: OutlinedButton.icon(
                        onPressed: () => ThemeColorPicker.open(context),
                        icon: const Icon(Icons.format_paint),
                        label: const Text('Theme'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const WidgetSpacer(height: 8),
                  Chip(
                    avatar: UserAvatarWidget(
                      url: EnterpriseSession.avatarUrl,
                      size: 24,
                    ),
                    label: Text(
                      EnterpriseSession.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    backgroundColor: colors.surfaceContainerHighest,
                    side: BorderSide.none,
                  ),
                  const WidgetSpacer(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: handleLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        foregroundColor: colors.error,
                        side: BorderSide(color: colors.error),
                      ),
                    ),
                  ),
                ] else ...[
                  Tooltip(
                    message: 'Theme Color',
                    child: IconButton(
                      onPressed: () => ThemeColorPicker.open(context),
                      icon: const Icon(Icons.format_paint),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  const WidgetSpacer(height: 8),
                  Tooltip(
                    message: 'Logout',
                    child: IconButton(
                      onPressed: handleLogout,
                      icon: const Icon(Icons.logout),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12.0),
                                child: Image.network(
                                  payload.attachmentUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const NetworkRecoveryFallbackWidget();
                                  },
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Container(
                                          height: 150,
                                          width: 200,
                                          color: colors.surfaceContainerHigh,
                                          child: const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      },
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

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Attach Image URL"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Paste a direct link to an image (Imgur, Discord, etc):",
              ),
              const WidgetSpacer(height: 12.0),
              TextField(
                controller: urlFieldController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "https://example.com/image.png",
                  filled: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                final String uriInput = urlFieldController.text.trim();
                if (uriInput.isNotEmpty &&
                    (uriInput.startsWith("http://") ||
                        uriInput.startsWith("https://"))) {
                  callback("", mediaUrl: uriInput);
                  Navigator.pop(dialogContext);
                  AlertBridge.showNotification(context, "Image attached.");
                } else {
                  AlertBridge.showNotification(
                    context,
                    "Please enter a valid HTTP/HTTPS URL.",
                    isFailureState: true,
                  );
                }
              },
              child: const Text("Send Image"),
            ),
          ],
        );
      },
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
