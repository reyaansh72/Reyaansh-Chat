import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:english_words/english_words.dart';
import 'dart:typed_data';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const FileTransferApp(),
    ),
  );
}

// --- ENUMS & MODELS ---

enum TransferProtocol { nearbyConnections, wifiDirect, bluetoothLegacy, httpUpload, tcpSocket }

class DeviceEndpoint {
  final String id;
  final String name;
  String group;

  DeviceEndpoint({required this.id, required this.name, this.group = 'Ungrouped'});
}

class TransferSession {
  final int payloadId;
  final String fileName;
  final int totalBytes;
  int bytesTransferred;
  final DateTime startTime;
  String status;

  TransferSession({
    required this.payloadId,
    required this.fileName,
    required this.totalBytes,
    this.bytesTransferred = 0,
    required this.startTime,
    this.status = 'Transferring',
  });

  double get progress => totalBytes == 0 ? 0 : bytesTransferred / totalBytes;
  
  double get speedKBps {
    final elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
    if (elapsedSeconds == 0) return 0;
    return (bytesTransferred / 1024) / elapsedSeconds;
  }

  Duration get remainingTime {
    final speed = speedKBps * 1024; // Bytes per sec
    if (speed == 0) return const Duration(seconds: 0);
    final remainingBytes = totalBytes - bytesTransferred;
    return Duration(seconds: (remainingBytes / speed).round());
  }
}

// --- STATE MANAGEMENT ---

class AppState extends ChangeNotifier {
  // Config
  Color seedColor = Colors.deepPurple;
  bool devOptionsEnabled = false;
  TransferProtocol selectedProtocol = TransferProtocol.nearbyConnections;
  late String deviceName;
  
  // Nearby State
  final Strategy strategy = Strategy.P2P_STAR;
  Map<String, DeviceEndpoint> discoveredDevices = {};
  String? connectedEndpointId;
  bool isAdvertising = false;
  bool isDiscovering = false;
  // Protocol settings
  String httpHost = '127.0.0.1';
  int httpPort = 8080;
  String tcpHost = '127.0.0.1';
  int tcpPort = 9000;
  int chunkSize = 64 * 1024; // 64KB
  String logLevel = 'info';
  bool simulateSlowNetwork = false;
  int _nextPayloadId = 1;
  // Persistence
  Map<String, String> persistedGroups = {};
  List<String> pendingSharedPaths = [];
  static const MethodChannel _platform = MethodChannel('app.channel.shared.data');
  
  // Transfer State
  Map<int, TransferSession> activeTransfers = {};
  List<String> logs = [];
  // Incoming connection prompt
  String? pendingConnectionId;
  String? pendingConnectionName;

  // Transfer history
  List<Map<String, dynamic>> transferHistory = [];

  AppState() {
    _generateDeviceName();
    _requestPermissions();
    _loadPreferences();
    _checkInitialShared();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final groupsJson = prefs.getString('device_groups');
      if (groupsJson != null && groupsJson.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(groupsJson);
        persistedGroups = decoded.map((k, v) => MapEntry(k, v.toString()));
      }
      // apply persisted groups to discoveredDevices entries if present
      for (final id in persistedGroups.keys) {
        if (discoveredDevices.containsKey(id)) {
          discoveredDevices[id]!.group = persistedGroups[id]!;
        }
      }
      final seed = prefs.getInt('seed_color');
      if (seed != null) {
        seedColor = Color(seed);
      }
      notifyListeners();
    } catch (e) {
      log('Prefs load error: $e');
    }
  }

  Future<void> _saveGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_groups', json.encode(persistedGroups));
    } catch (e) {
      log('Prefs save error: $e');
    }
  }

  Future<void> _checkInitialShared() async {
    try {
      final res = await _platform.invokeMethod<List>('getInitialSharedFiles');
      if (res != null && res.isNotEmpty) {
        pendingSharedPaths = res.whereType<String>().toList();
        log('Received ${pendingSharedPaths.length} shared items');
        notifyListeners();
      }
    } catch (e) {
      // ignore if channel not present on other platforms
    }
  }

  void _generateDeviceName() {
    final pair = generateWordPairs().first;
    deviceName = "${pair.first} ${pair.second}".toUpperCase();
    notifyListeners();
  }

  void log(String message) {
    logs.insert(0, "${DateTime.now().toIso8601String().split('T').last}: $message");
    notifyListeners();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();
    log("Permissions requested");
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('transfer_history');
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw) as List<dynamic>;
        transferHistory = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      log('History load error: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('transfer_history', json.encode(transferHistory));
    } catch (e) {
      log('History save error: $e');
    }
  }

  void updateThemeColor(Color color) {
    seedColor = color;
    // persist
    SharedPreferences.getInstance().then((prefs) => prefs.setInt('seed_color', color.value));
    notifyListeners();
  }

  void toggleDevOptions(bool value) {
    devOptionsEnabled = value;
    notifyListeners();
  }

  void setProtocol(TransferProtocol protocol) {
    selectedProtocol = protocol;
    log("Protocol switched to ${protocol.name}");
    notifyListeners();
  }

  void setHttpEndpoint(String host, int port) {
    httpHost = host;
    httpPort = port;
    log('HTTP endpoint set to $host:$port');
    notifyListeners();
  }

  void setTcpEndpoint(String host, int port) {
    tcpHost = host;
    tcpPort = port;
    log('TCP endpoint set to $host:$port');
    notifyListeners();
  }

  void setChunkSize(int size) {
    chunkSize = size;
    log('Chunk size set to ${size}B');
    notifyListeners();
  }

  void setLogLevel(String level) {
    logLevel = level;
    log('Log level: $level');
    notifyListeners();
  }

  void setSimulateSlowNetwork(bool v) {
    simulateSlowNetwork = v;
    log('Simulate slow network: $v');
    notifyListeners();
  }
  
  void assignGroup(String id, String group) {
    if (discoveredDevices.containsKey(id)) {
      discoveredDevices[id]!.group = group;
      persistedGroups[id] = group;
      _saveGroups();
      notifyListeners();
    }
  }

  Future<void> sendPendingTo(String endpointId) async {
    if (pendingSharedPaths.isEmpty) return;
    await sendFiles(endpointId, pendingSharedPaths);
    pendingSharedPaths.clear();
    notifyListeners();
  }

  // --- CORE NETWORKING (NEARBY CONNECTIONS) ---

  Future<void> toggleAdvertising() async {
    if (isAdvertising) {
      await Nearby().stopAdvertising();
      isAdvertising = false;
      log("Stopped advertising");
    } else {
      try {
        // Advertise with a receiver marker so discoverers can filter
        final advertiseName = 'BEAM_RECV:$deviceName';
        bool a = await Nearby().startAdvertising(
          advertiseName,
          strategy,
          onConnectionInitiated: _onConnectionInitiated,
          onConnectionResult: (id, status) {
            log("Advertising connection result: $status");
            if (status == Status.CONNECTED) connectedEndpointId = id;
            notifyListeners();
          },
          onDisconnected: (id) {
            connectedEndpointId = null;
            log("Disconnected from $id");
            notifyListeners();
          },
        );
        isAdvertising = a;
        log("Started advertising: $deviceName");
      } catch (e) {
        log("Advertise Error: $e");
      }
    }
    notifyListeners();
  }

  Future<void> toggleDiscovery() async {
    if (isDiscovering) {
      await Nearby().stopDiscovery();
      discoveredDevices.clear();
      isDiscovering = false;
      log("Stopped discovery");
    } else {
      try {
        // Discover devices and only show those advertising as our receiver app
        bool d = await Nearby().startDiscovery(
          deviceName,
          strategy,
          onEndpointFound: (id, name, serviceId) {
            // Filter for endpoints that are in receiver mode
            if (name.startsWith('BEAM_RECV:')) {
              final pretty = name.replaceFirst('BEAM_RECV:', '');
              discoveredDevices[id] = DeviceEndpoint(id: id, name: pretty);
              log("Found receiver device: $pretty");
            } else {
              // ignore non-app endpoints
              return;
            }
            notifyListeners();
          },
          onEndpointLost: (id) {
            discoveredDevices.remove(id);
            log("Lost device: $id");
            notifyListeners();
          },
        );
        isDiscovering = d;
        log("Started discovering");
      } catch (e) {
        log("Discovery Error: $e");
      }
    }
    notifyListeners();
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) async {
    log("Connection initiated with ${info.endpointName}");
    // Save pending connection and prompt the UI to accept/decline
    pendingConnectionId = id;
    pendingConnectionName = info.endpointName;
    notifyListeners();
  }

  Future<void> acceptPendingConnection() async {
    final id = pendingConnectionId;
    if (id == null) return;
    pendingConnectionId = null;
    pendingConnectionName = null;
    notifyListeners();
    await Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endId, payload) async {
        if (payload.type == PayloadType.FILE) {
          log("Receiving file... ID: ${payload.id}");
          activeTransfers[payload.id] = TransferSession(
            payloadId: payload.id,
            fileName: "Received_File_${payload.id}", 
            totalBytes: 1000000, // Dummy size until update triggers
            startTime: DateTime.now(),
          );
          notifyListeners();
        }
      },
      onPayloadTransferUpdate: (endId, update) {
        if (activeTransfers.containsKey(update.id)) {
          final session = activeTransfers[update.id]!;
          session.bytesTransferred = update.bytesTransferred;
          if (update.totalBytes > 0) {
            activeTransfers[update.id] = TransferSession(
              payloadId: session.payloadId,
              fileName: session.fileName,
              totalBytes: update.totalBytes,
              bytesTransferred: update.bytesTransferred,
              startTime: session.startTime,
              status: update.status == PayloadStatus.SUCCESS ? 'Complete' : 'Transferring',
            );
          }
          if (update.status == PayloadStatus.SUCCESS) {
            log("Transfer ${update.id} COMPLETE.");
            // add to history
            transferHistory.insert(0, {
              'fileName': session.fileName,
              'size': update.totalBytes,
              'timestamp': DateTime.now().toIso8601String(),
            });
            _saveHistory();
          }
          notifyListeners();
        }
      },
    );
  }

  Future<void> declinePendingConnection() async {
    final id = pendingConnectionId;
    if (id == null) return;
    try {
      await Nearby().rejectConnection(id);
    } catch (_) {}
    pendingConnectionId = null;
    pendingConnectionName = null;
    notifyListeners();
  }

  Future<void> requestConnection(String endpointId) async {
    log("Requesting connection to $endpointId");
    await Nearby().requestConnection(
      deviceName,
      endpointId,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: (id, status) {
        log("Discovery connection result: $status");
        if (status == Status.CONNECTED) connectedEndpointId = id;
        notifyListeners();
      },
      onDisconnected: (id) {
        connectedEndpointId = null;
        log("Disconnected from $id");
        notifyListeners();
      },
    );
  }
  Future<void> sendFile(String? endpointId) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    File file = File(result.files.single.path!);

    // Route based on selected protocol
    switch (selectedProtocol) {
      case TransferProtocol.nearbyConnections:
        if (endpointId == null) {
          log('No endpoint selected for Nearby Connections');
          return;
        }
        int payloadId = await Nearby().sendFilePayload(endpointId, file.path);
        activeTransfers[payloadId] = TransferSession(
          payloadId: payloadId,
          fileName: result.files.single.name,
          totalBytes: await file.length(),
          startTime: DateTime.now(),
        );
        log("Sending file ${result.files.single.name} via Nearby");
        break;

      case TransferProtocol.httpUpload:
        await _sendFileHttp(file, result.files.single.name);
        break;

      case TransferProtocol.tcpSocket:
        await _sendFileTcp(file, result.files.single.name);
        break;

      default:
        log('Selected protocol not implemented yet');
    }
    notifyListeners();
  }

  // Send multiple files (Nearby Connections) — loops per file
  Future<void> sendFiles(String endpointId, List<String> paths) async {
    for (final p in paths) {
      try {
        final payloadId = await Nearby().sendFilePayload(endpointId, p);
        final f = File(p);
        activeTransfers[payloadId] = TransferSession(
          payloadId: payloadId,
          fileName: p.split(Platform.pathSeparator).last,
          totalBytes: await f.length(),
          startTime: DateTime.now(),
        );
        log('Sending ${p.split(Platform.pathSeparator).last} to $endpointId');
      } catch (e) {
        log('Error sending $p: $e');
      }
    }
    notifyListeners();
  }

  Future<void> _sendFileHttp(File file, String fileName) async {
    final uri = Uri.parse('http://$httpHost:$httpPort/upload');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', file.path, filename: fileName));

    final payloadId = _nextPayloadId++;
    activeTransfers[payloadId] = TransferSession(
      payloadId: payloadId,
      fileName: fileName,
      totalBytes: await file.length(),
      startTime: DateTime.now(),
    );
    log('HTTP upload started to $uri');

    try {
      final streamed = await request.send();
      // Simple progress approximation: wait for completion
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        activeTransfers[payloadId] = TransferSession(
          payloadId: payloadId,
          fileName: fileName,
          totalBytes: await file.length(),
          bytesTransferred: await file.length(),
          startTime: DateTime.now(),
          status: 'Complete',
        );
        log('HTTP upload complete');
      } else {
        log('HTTP upload failed: ${resp.statusCode}');
        activeTransfers.remove(payloadId);
      }
    } catch (e) {
      log('HTTP upload error: $e');
      activeTransfers.remove(payloadId);
    }
  }

  Future<void> _sendFileTcp(File file, String fileName) async {
    final payloadId = _nextPayloadId++;
    activeTransfers[payloadId] = TransferSession(
      payloadId: payloadId,
      fileName: fileName,
      totalBytes: await file.length(),
      startTime: DateTime.now(),
    );

    try {
      final socket = await Socket.connect(tcpHost, tcpPort, timeout: const Duration(seconds: 5));
      log('TCP connected to $tcpHost:$tcpPort');

      // Send a simple header: filename length (4 bytes) + filesize (8 bytes) + filename
      final nameBytes = utf8.encode(fileName);
      final fileLen = await file.length();
      final header = Uint8List(12); // 4 + 8
      final headerView = ByteData.sublistView(header);
      headerView.setUint32(0, nameBytes.length);
      headerView.setUint64(4, fileLen);
      socket.add(header);
      socket.add(nameBytes);

      final raf = file.openRead();
      await for (final chunk in raf) {
        socket.add(chunk);
        // naive bookkeeping
        final session = activeTransfers[payloadId]!;
        session.bytesTransferred += chunk.length;
        notifyListeners();
        if (simulateSlowNetwork) await Future.delayed(const Duration(milliseconds: 50));
      }

      await socket.flush();
      socket.destroy();
      activeTransfers[payloadId] = TransferSession(
        payloadId: payloadId,
        fileName: fileName,
        totalBytes: await file.length(),
        bytesTransferred: await file.length(),
        startTime: DateTime.now(),
        status: 'Complete',
      );
      log('TCP upload complete');
    } catch (e) {
      log('TCP upload error: $e');
      activeTransfers.remove(payloadId);
    }
  }
}

// --- UI COMPONENTS ---

class FileTransferApp extends StatelessWidget {
  const FileTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seedColor = context.select((AppState s) => s.seedColor);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        ColorScheme lightScheme = ColorScheme.fromSeed(seedColor: seedColor);
        ColorScheme darkScheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark);

        if (lightDynamic != null && darkDynamic != null) {
          lightScheme = lightDynamic.harmonized();
          darkScheme = darkDynamic.harmonized();
        }

        return MaterialApp(
          title: 'Beam',
          theme: ThemeData(useMaterial3: true, colorScheme: lightScheme),
          darkTheme: ThemeData(useMaterial3: true, colorScheme: darkScheme),
          themeMode: ThemeMode.system,
          home: const HomeScreen(), // Updated to Stateful
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // start discovery on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (!appState.isDiscovering) appState.toggleDiscovery();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final appState = context.read<AppState>();
    if (state == AppLifecycleState.resumed) {
      if (!appState.isDiscovering) appState.toggleDiscovery();
    } else if (state == AppLifecycleState.paused) {
      if (appState.isDiscovering) appState.toggleDiscovery();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // If there's a pending incoming connection, prompt accept/decline
    if (state.pendingConnectionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Incoming Connection'),
            content: Text('Accept connection from ${state.pendingConnectionName ?? 'unknown'}?'),
            actions: [
              TextButton(onPressed: () { context.read<AppState>().declinePendingConnection(); Navigator.pop(context); }, child: const Text('Decline')),
              ElevatedButton(onPressed: () { context.read<AppState>().acceptPendingConnection(); Navigator.pop(context); }, child: const Text('Accept')),
            ],
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Beam Drop", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("You are: ${state.deviceName}", style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferHistoryScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Controls & incoming shared banner
            if (state.pendingSharedPaths.isNotEmpty) ...[
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.share, color: Colors.white),
                  title: Text('${state.pendingSharedPaths.length} file(s) received via Share'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      // choose a receiver to send to
                      showModalBottomSheet(
                        context: context,
                        builder: (_) => Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Send shared files to...', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              ...state.discoveredDevices.values.map((d) => ListTile(
                                title: Text(d.name),
                                onTap: () {
                                  Navigator.pop(context);
                                  state.sendPendingTo(d.id);
                                },
                              ))
                            ],
                          ),
                        ),
                      );
                    },
                    child: const Text('Pick Receiver'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: Icon(state.isAdvertising ? Icons.sensors_off : Icons.sensors),
                    label: Text(state.isAdvertising ? "Stop Receiving" : "Receive Files"),
                    onPressed: state.toggleAdvertising,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    icon: Icon(state.isDiscovering ? Icons.stop : Icons.search),
                    label: Text(state.isDiscovering ? "Stop Scan" : "Find Nearby"),
                    onPressed: state.toggleDiscovery,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Discovered Devices
            Text("Nearby Devices", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Expanded(
              flex: 2,
              child: state.discoveredDevices.isEmpty
                  ? Center(child: Text("No nearby receivers found", style: TextStyle(color: Theme.of(context).colorScheme.outline)))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: state.discoveredDevices.length,
                      itemBuilder: (context, index) {
                        final device = state.discoveredDevices.values.elementAt(index);
                        final isConnected = state.connectedEndpointId == device.id;
                        return GestureDetector(
                          onTap: () async {
                            // when tapped, show file picker and send
                            final result = await FilePicker.platform.pickFiles(allowMultiple: true);
                            if (result != null && result.files.isNotEmpty) {
                              final paths = result.files.map((f) => f.path!).whereType<String>().toList();
                              // show confirm bottom sheet
                              showModalBottomSheet(
                                context: context,
                                builder: (_) => Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Send to ${device.name}', style: Theme.of(context).textTheme.titleMedium),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 120,
                                        child: ListView(
                                          children: paths.map((p) => ListTile(
                                            leading: const Icon(Icons.insert_drive_file),
                                            title: Text(p.split(Platform.pathSeparator).last),
                                            subtitle: Text('${(File(p).lengthSync() / 1024).round()} KB'),
                                          )).toList(),
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                          ElevatedButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              state.sendFiles(device.id, paths);
                                            },
                                            child: const Text('Send'),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            }
                          },
                          onLongPress: () => state.requestConnection(device.id),
                          child: Card(
                            elevation: 2,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(radius: 28, backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: const Icon(Icons.wifi_tethering)),
                                const SizedBox(height: 8),
                                Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(isConnected ? 'Connected' : 'Tap to send', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Active Transfers
            if (state.activeTransfers.isNotEmpty) ...[
              const Divider(),
              Text("Transfers", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Expanded(
                flex: 1,
                child: ListView.builder(
                  itemCount: state.activeTransfers.length,
                  itemBuilder: (context, index) {
                    final session = state.activeTransfers.values.elementAt(index);
                    return TransferCard(session: session);
                  },
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class TransferCard extends StatelessWidget {
  final TransferSession session;
  const TransferCard({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(session.fileName, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                Text(session.status, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              tween: Tween<double>(begin: 0, end: session.progress),
              builder: (context, value, _) => LinearProgressIndicator(value: value, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${session.speedKBps.toStringAsFixed(1)} KB/s"),
                Text("${session.remainingTime.inSeconds}s remaining"),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text("Theme Color"),
            subtitle: const Text("Override Material You color"),
            trailing: CircleAvatar(backgroundColor: state.seedColor, radius: 12),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Pick a color'),
                    content: SingleChildScrollView(
                      child: ColorPicker(
                        pickerColor: state.seedColor,
                        onColorChanged: context.read<AppState>().updateThemeColor,
                        pickerAreaHeightPercent: 0.8,
                      ),
                    ),
                    actions: [
                      TextButton(
                        child: const Text('Got it'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          // Fast mode: Nearby Connections only
          ListTile(
            leading: const Icon(Icons.flash_on, color: Colors.orangeAccent),
            title: const Text('Fast Mode (Nearby)'),
            subtitle: const Text('Uses Nearby Connections for low-latency transfers'),
          ),

          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('Chunk Size (KB)'),
            subtitle: Text('${(state.chunkSize / 1024).round()} KB'),
            onTap: () {
              final ctrl = TextEditingController(text: (state.chunkSize ~/ 1024).toString());
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Chunk Size (KB)'),
                  content: TextField(controller: ctrl, keyboardType: TextInputType.number),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        final kb = int.tryParse(ctrl.text.trim()) ?? (state.chunkSize ~/ 1024);
                        context.read<AppState>().setChunkSize(kb * 1024);
                        Navigator.pop(context);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.rule),
            title: const Text('Log Level'),
            subtitle: Text(state.logLevel),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => SimpleDialog(
                  title: const Text('Log Level'),
                  children: ['debug', 'info', 'warn', 'error'].map((l) => SimpleDialogOption(
                    onPressed: () { context.read<AppState>().setLogLevel(l); Navigator.pop(context); },
                    child: Text(l),
                  )).toList(),
                ),
              );
            },
          ),

          SwitchListTile(
            secondary: const Icon(Icons.speed),
            title: const Text('Simulate Slow Network'),
            subtitle: const Text('Insert small delays during transfers'),
            value: state.simulateSlowNetwork,
            onChanged: (v) => context.read<AppState>().setSimulateSlowNetwork(v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.developer_mode),
            title: const Text("Developer Options"),
            subtitle: const Text("Enable advanced debugging features"),
            value: state.devOptionsEnabled,
            onChanged: context.read<AppState>().toggleDevOptions,
          ),
          if (state.devOptionsEnabled) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.terminal, color: Colors.redAccent),
              title: const Text("Open Dev Console", style: TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DevConsoleScreen())),
            )
          ]
        ],
      ),
    );
  }
}

class DevConsoleScreen extends StatelessWidget {
  const DevConsoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text("Developer Console")),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => state.log("Test Log Injected"),
                child: const Text("Inject Log"),
              ),
              ElevatedButton(
                onPressed: () => context.read<AppState>().logs.clear(),
                child: const Text("Clear"),
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: state.logs.length,
              itemBuilder: (context, index) {
                return Text(
                  state.logs[index],
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

class SendPreviewPage extends StatefulWidget {
  final DeviceEndpoint device;
  final List<String> paths;
  const SendPreviewPage({super.key, required this.device, required this.paths});

  @override
  State<SendPreviewPage> createState() => _SendPreviewPageState();
}

class _SendPreviewPageState extends State<SendPreviewPage> with SingleTickerProviderStateMixin {
  bool sending = false;
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _startSend() async {
    setState(() => sending = true);
    await _anim.forward();
    // call send
    await context.read<AppState>().sendFiles(widget.device.id, widget.paths);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Files sent')));
    await Future.delayed(const Duration(milliseconds: 200));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Send to ${widget.device.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Hero(tag: widget.device.id, child: CircleAvatar(radius: 48, backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: const Icon(Icons.wifi_tethering, size: 36))),
            const SizedBox(height: 12),
            Text(widget.device.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Expanded(child: ListView(children: widget.paths.map((p) => ListTile(leading: const Icon(Icons.insert_drive_file), title: Text(p.split(Platform.pathSeparator).last), subtitle: Text('${(File(p).lengthSync() / 1024).round()} KB'))).toList())),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: sending ? 0.8 : 1.0),
              duration: const Duration(milliseconds: 300),
              builder: (context, s, _) => Transform.scale(
                scale: s,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: sending ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white) : const Icon(Icons.send),
                    label: Text(sending ? 'Sending...' : 'Send'),
                    onPressed: sending ? null : _startSend,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class TransferHistoryScreen extends StatelessWidget {
  const TransferHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer History')),
      body: ListView.builder(
        itemCount: state.transferHistory.length,
        itemBuilder: (context, index) {
          final h = state.transferHistory[index];
          return ListTile(
            leading: const Icon(Icons.insert_drive_file),
            title: Text(h['fileName'] ?? 'Unknown'),
            subtitle: Text('${(h['size'] ?? 0)} bytes • ${h['timestamp'] ?? ''}'),
          );
        },
      ),
    );
  }
}