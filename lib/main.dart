import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  // 1. Finalizes low-level platform channels and loops
  AppInitializer.setupHardwareAcceleration();

  // 2. Initialise the native Firebase core engine architecture
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. Mount and build the Material 3 app workspace tree
  runApp(const ReyaanshCoreApp());
}

// =========================================================================
// 1. GLOBAL SESSION STATE (ONE-TIME LOGIN CONFIG)
// =========================================================================

class EnterpriseSession {
  static String userId = '';
  static String username = '';
  static String avatarUrl = '';

  static void initialize(String name, String avatar) {
    // Generate a unique session ID for the user to distinguish 'me' from 'others'
    userId =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
    username = name;
    avatarUrl = avatar;
  }
}

// =========================================================================
// 2. MASTER BRANDING & MATERIAL 3 THEME CONFIGURATION
// =========================================================================

class ReyaanshCoreApp extends StatelessWidget {
  const ReyaanshCoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reyaansh Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFCDDC39), // High-vibrancy Lime-Yellowish
          brightness: Brightness.light,
        ).copyWith(surfaceContainerHigh: const Color(0xFFF4F6E7)),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 16.0, fontWeight: FontWeight.normal),
          bodyMedium: TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal),
          labelSmall: TextStyle(fontSize: 11.0, color: Colors.grey),
        ),
      ),
      home: const LoginScreen(),
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

    EnterpriseSession.initialize(name, avatar);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ChatDashboard()),
    );
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
                      'Test',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const WidgetSpacer(height: 8),
                    Text(
                      'Set up your profile to join the global chat',
                      style: TextStyle(color: colors.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const WidgetSpacer(height: 32),
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
                        child: const Text(
                          'Join Chat',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
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

  const ChatPayload({
    required this.id,
    required this.message,
    this.attachmentUrl,
    required this.timestamp,
    required this.senderId,
    required this.senderName,
    required this.senderAvatarUrl,
  });

  factory ChatPayload.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatPayload(
      id: doc.id,
      message: data['text'] ?? '',
      attachmentUrl: data['mediaUrl'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown User',
      senderAvatarUrl: data['senderAvatarUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': message,
      'mediaUrl': attachmentUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
    };
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

  late final Stream<QuerySnapshot> _firestoreStream;

  @override
  void initState() {
    super.initState();
    _firestoreStream = FirebaseFirestore.instance
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
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

    FirebaseFirestore.instance.collection('messages').add({
      'text': content.trim(),
      'mediaUrl': mediaUrl,
      'timestamp': FieldValue.serverTimestamp(),
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

    return Scaffold(
      backgroundColor: colors.surfaceContainerHigh,
      appBar: AppBar(
        title: const Text(
          'Community Chat',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
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
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestoreStream,
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

                        final docs = snapshot.data!.docs;

                        if (docs.isEmpty) {
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
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final payload = ChatPayload.fromFirestore(
                              docs[index],
                            );
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
                                        if (loadingProgress == null)
                                          return child;
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
  final String messageText;

  const EmoteContextActionWrapper({
    super.key,
    required this.child,
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
                  children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emote) {
                    return TouchFeedbackEnhancer(
                      onTap: () {
                        Navigator.pop(context);
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
// 10. MEDIA ATTACHMENT PIPELINE & CONTROLLER
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
