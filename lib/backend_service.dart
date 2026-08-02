import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BackendService {
  BackendService._();

  static const String firebaseMode = 'firebase';
  static const String localMode = 'local';
  static final BackendService instance = BackendService._();

  late SharedPreferences _prefs;
  String _mode = firebaseMode;
  String _baseUrl = 'http://127.0.0.1:3000';
  bool _initialized = false;

  bool get initialized => _initialized;
  bool get isLocal => _mode == localMode;
  String get mode => _mode;
  String get baseUrl => _baseUrl;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _mode = _prefs.getString('backendMode') ?? firebaseMode;
    _baseUrl = _prefs.getString('backendBaseUrl') ?? 'http://127.0.0.1:3000';
    _initialized = true;
  }

  Future<void> setBackend({required String mode, required String baseUrl}) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    _mode = mode;
    _baseUrl = normalizedBaseUrl;
    await _prefs.setString('backendMode', mode);
    await _prefs.setString('backendBaseUrl', normalizedBaseUrl);
  }

  String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'http://127.0.0.1:3000';
    }
    final withoutSlash = trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    if (withoutSlash.startsWith('http://') || withoutSlash.startsWith('https://')) {
      return withoutSlash;
    }
    return 'http://$withoutSlash';
  }

  Uri _buildUri(String path) {
    final cleanedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$cleanedPath');
  }

  dynamic _normalizeValue(dynamic value) {
    if (value is Map) {
      if (value is Map<String, dynamic> && value.containsKey('.sv') && value['.sv'] == 'timestamp') {
        return DateTime.now().millisecondsSinceEpoch;
      }
      final normalized = <String, dynamic>{};
      value.forEach((key, child) {
        normalized[key.toString()] = _normalizeValue(child);
      });
      return normalized;
    }
    if (value is List) {
      return value.map(_normalizeValue).toList();
    }
    return value;
  }

  Future<http.Response> _get(String path) async {
    return http.get(_buildUri(path), headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 8));
  }

  Future<http.Response> _post(String path, {Map<String, dynamic>? body}) async {
    final payload = body == null ? null : jsonEncode(_normalizeValue(body));
    return http.post(
      _buildUri(path),
      headers: {'Content-Type': 'application/json'},
      body: payload,
    ).timeout(const Duration(seconds: 8));
  }

  Future<bool> testConnection({String? baseUrl}) async {
    final targetBaseUrl = _normalizeBaseUrl(baseUrl ?? _baseUrl);
    if (targetBaseUrl.isEmpty) {
      return false;
    }
    try {
      final response = await http.get(Uri.parse('$targetBaseUrl/api/health')).timeout(const Duration(seconds: 4));
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<void> uploadFile({required String fileName, required String mimeType, required String contentBase64}) async {
    if (!isLocal) {
      return;
    }

    final response = await _post('/api/upload', body: {
      'name': fileName,
      'mimeType': mimeType,
      'contentBase64': contentBase64,
    });
    if (response.statusCode >= 400) {
      throw Exception('Upload failed: ${response.body}');
    }
  }

  Future<String> uploadFileAndGetUrl({required String fileName, required String mimeType, required String contentBase64}) async {
    if (!isLocal) {
      return '';
    }

    final response = await _post('/api/upload', body: {
      'name': fileName,
      'mimeType': mimeType,
      'contentBase64': contentBase64,
    });
    if (response.statusCode >= 400) {
      throw Exception('Upload failed: ${response.body}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rawUrl = payload['url']?.toString() ?? '';
    if (rawUrl.isEmpty) {
      return '';
    }
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }
    return rawUrl.startsWith('/') ? '$_baseUrl$rawUrl' : '$_baseUrl/$rawUrl';
  }

  Future<void> persistProfile(String userId, Map<String, dynamic> profile) async {
    if (isLocal) {
      final response = await _post('/api/users/$userId', body: profile);
      if (response.statusCode >= 400) {
        throw Exception('Local profile sync failed');
      }
      return;
    }

    await FirebaseDatabase.instance.ref('users/$userId').set(profile);
  }

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    if (isLocal) {
      final response = await _get('/api/users/$userId');
      if (response.statusCode >= 400) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded as Map);
      }
      return null;
    }

    final snapshot = await FirebaseDatabase.instance.ref('users/$userId').get();
    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }
    final raw = snapshot.value as Map<dynamic, dynamic>;
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<List<Map<String, dynamic>>> listProfiles() async {
    if (isLocal) {
      final response = await _get('/api/users');
      if (response.statusCode >= 400) {
        return <Map<String, dynamic>>[];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      return <Map<String, dynamic>>[];
    }

    final snapshot = await FirebaseDatabase.instance.ref('users').get();
    if (!snapshot.exists || snapshot.value == null) {
      return <Map<String, dynamic>>[];
    }

    final data = snapshot.value as Map<dynamic, dynamic>;
    final users = <Map<String, dynamic>>[];
    data.forEach((key, value) {
      if (value is Map) {
        final map = Map<String, dynamic>.from(value as Map);
        map['userId'] = key.toString();
        users.add(map);
      }
    });
    return users;
  }

  Future<void> setValue(String path, Map<String, dynamic> payload) async {
    if (isLocal) {
      final response = await _post('/api/value/$path', body: payload);
      if (response.statusCode >= 400) {
        throw Exception('Local write failed');
      }
      return;
    }

    await FirebaseDatabase.instance.ref(path).set(payload);
  }

  Future<Map<String, dynamic>?> readValue(String path) async {
    if (isLocal) {
      final response = await _get('/api/value/$path');
      if (response.statusCode >= 400) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded as Map);
      }
      return null;
    }

    final snapshot = await FirebaseDatabase.instance.ref(path).get();
    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }
    final raw = snapshot.value as Map<dynamic, dynamic>;
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<void> appendCollectionItem(String path, Map<String, dynamic> item) async {
    if (isLocal) {
      final response = await _post('/api/collection/$path', body: item);
      if (response.statusCode >= 400) {
        throw Exception('Local collection write failed');
      }
      return;
    }

    await FirebaseDatabase.instance.ref(path).push().set(item);
  }

  Future<List<Map<String, dynamic>>> readCollectionItems(String path) async {
    if (isLocal) {
      final response = await _get('/api/collection/$path');
      if (response.statusCode >= 400) {
        return <Map<String, dynamic>>[];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      return <Map<String, dynamic>>[];
    }

    final snapshot = await FirebaseDatabase.instance.ref(path).get();
    if (!snapshot.exists || snapshot.value == null) {
      return <Map<String, dynamic>>[];
    }

    final raw = snapshot.value as Map<dynamic, dynamic>;
    return raw.entries
        .map((entry) {
          final value = entry.value;
          if (value is Map) {
            final map = Map<String, dynamic>.from(value as Map);
            map['id'] = entry.key.toString();
            return map;
          }
          return <String, dynamic>{'id': entry.key.toString(), 'value': value};
        })
        .toList();
  }
}
