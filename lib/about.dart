import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AboutDevicePage extends StatefulWidget {
  const AboutDevicePage({super.key});

  @override
  State<AboutDevicePage> createState() => _AboutDevicePageState();
}

class _AboutDevicePageState extends State<AboutDevicePage> {
  final Map<String, String> _deviceData = {};
  bool _loading = true;
  String? _error;
  Color _seedColor = const Color(0xFF6750A4);
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    final plugin = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        final info = await plugin.webBrowserInfo;
        _deviceData.addAll({
          'Platform': 'Web',
          'Browser Name': info.browserName.name,
          'App Version': info.appVersion ?? 'Unknown',
          'User Agent': info.userAgent ?? 'Unknown',
          'Vendor': info.vendor ?? 'Unknown',
          'Hardware Concurrency': '${info.hardwareConcurrency}',
        });
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await plugin.androidInfo;
        _deviceData.addAll({
          'Platform': 'Android',
          'Brand': info.brand,
          'Model': info.model,
          'Android Version': info.version.release,
          'SDK Int': '${info.version.sdkInt}',
          'Device': info.device,
          'Manufacturer': info.manufacturer,
          'Board': info.board,
          'Hardware': info.hardware,
        });
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await plugin.iosInfo;
        _deviceData.addAll({
          'Platform': 'iOS',
          'Model': info.utsname.machine,
          'System Name': info.systemName,
          'System Version': info.systemVersion,
          'Name': info.name,
          'Identifier For Vendor': info.identifierForVendor ?? 'Unknown',
        });
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final info = await plugin.macOsInfo;
        _deviceData.addAll({
          'Platform': 'macOS',
          'Host Name': info.hostName,
          'Model': info.model,
          'OS Release': info.osRelease,
          'Kernel Version': info.kernelVersion,
          'Major Version': '${info.majorVersion}',
          'Minor Version': '${info.minorVersion}',
          'Patch Version': '${info.patchVersion}',
        });
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        final info = await plugin.windowsInfo;
        _deviceData.addAll({
          'Platform': 'Windows',
          'Computer Name': info.computerName,
          'Number Of Cores': '${info.numberOfCores}',
          'System Memory In Megabytes': '${info.systemMemoryInMegabytes}',
          'Major Version': '${info.majorVersion}',
          'Minor Version': '${info.minorVersion}',
          'Build Number': '${info.buildNumber}',
        });
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        final info = await plugin.linuxInfo;
        _deviceData.addAll({
          'Platform': 'Linux',
          'Name': info.name,
          'Version': info.version ?? 'Unknown',
          'Pretty Name': info.prettyName,
          'Machine ID': info.machineId ?? 'Unknown',
          'ID': info.id,
        });
      } else {
        _deviceData['Platform'] = defaultTargetPlatform.name;
      }
    } catch (error) {
      _error = error.toString();
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

  void _toggleThemeMode() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
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
          title: const Text('About Device'),
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
            : _error != null
                ? Center(child: Text('Failed to load device info: $_error'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _deviceData.length,
                    separatorBuilder: (_, __) => const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final key = _deviceData.keys.elementAt(index);
                      return ListTile(
                        title: Text(key),
                        subtitle: Text(_deviceData[key] ?? 'Unknown'),
                      );
                    },
                  ),
      ),
    );
  }
}
