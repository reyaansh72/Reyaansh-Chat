import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path_provider/path_provider.dart';

import 'firebase_options.dart';

class ReyaanshNotesApp extends StatefulWidget {
  const ReyaanshNotesApp({super.key});

  @override
  State<ReyaanshNotesApp> createState() => _ReyaanshNotesAppState();
}

class _ReyaanshNotesAppState extends State<ReyaanshNotesApp> {
  Color _seedColor = const Color(0xFF6750A4);
  Color _penColor = Colors.black;
  Color _pageColor = Colors.white;
  double _penSize = 3.0;
  bool _isDrawMode = false;
  bool _laserMode = false;
  bool _softPen = true;
  final double _penSoftness = 2.0;
  NoteTemplateStyle _templateStyle = NoteTemplateStyle.plain;
  final TextEditingController _noteController = TextEditingController();
  final List<List<DrawPoint>> _strokes = <List<DrawPoint>>[];
  final List<NoteImage> _images = <NoteImage>[];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickThemeColor(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Material You color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _seedColor,
              onColorChanged: (color) => setState(() => _seedColor = color),
              labelTypes: const [],
              pickerAreaHeightPercent: 0.65,
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

  Future<void> _pickPenColor(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Pick pen color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _penColor,
              onColorChanged: (color) => setState(() => _penColor = color),
              labelTypes: const [],
              pickerAreaHeightPercent: 0.65,
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

  Future<void> _showPageSettings(BuildContext context) async {
    Color selectedColor = _pageColor;
    NoteTemplateStyle selectedTemplate = _templateStyle;
    final theme = Theme.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Page Settings'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Page color', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ColorPicker(
                      pickerColor: selectedColor,
                      onColorChanged: (color) => setDialogState(() => selectedColor = color),
                      labelTypes: const [],
                      pickerAreaHeightPercent: 0.45,
                      enableAlpha: false,
                    ),
                    const SizedBox(height: 20),
                    Text('Template', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: NoteTemplateStyle.values.map((style) {
                        return ChoiceChip(
                          label: Text(style.name),
                          selected: selectedTemplate == style,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => selectedTemplate = style);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _pageColor = selectedColor;
                      _templateStyle = selectedTemplate;
                    });
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) {
      return;
    }

    final path = result.files.first.path;
    if (path == null) {
      return;
    }

    setState(() {
      _images.add(NoteImage(path: path, offset: const Offset(16, 16), scale: 1.0));
    });
  }

  Future<void> _exportNote() async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/reyaansh_notes_${DateTime.now().millisecondsSinceEpoch}.txt');
      final content = StringBuffer();
      content.writeln('Reyaansh Notes Export');
      content.writeln('Template: ${_templateStyle.name}');
      content.writeln('Page color: ${_pageColor.toARGB32().toRadixString(16)}');
      content.writeln('Drawing mode: $_isDrawMode');
      content.writeln('Laser mode: $_laserMode');
      content.writeln('Pen color: ${_penColor.toARGB32().toRadixString(16)}');
      content.writeln('Pen size: ${_penSize.toStringAsFixed(1)}');
      content.writeln('---');
      content.writeln(_noteController.text);
      content.writeln('--- Images: ${_images.length}');
      for (final image in _images) {
        content.writeln('Image: ${image.path}');
      }
      await file.writeAsString(content.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Note exported to ${file.path}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $error')),
      );
    }
  }

  Future<void> _publishNoteToFirebase() async {
    final title = 'Note ${DateTime.now().millisecondsSinceEpoch}';
    final content = _noteController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Write a note before publishing.')));
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      final notesRef = FirebaseDatabase.instance.ref('notes').push();
      await notesRef.set({
        'title': title,
        'content': content,
        'pageColor': _pageColor.value.toRadixString(16),
        'template': _templateStyle.name,
        'publishedAt': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note published to Firebase.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publish failed: $error')));
    }
  }

  void _clearDrawing() {
    setState(() {
      _strokes.clear();
    });
  }

  void _clearNoteText() {
    setState(() {
      _noteController.clear();
    });
  }

  void _undoStroke() {
    setState(() {
      if (_strokes.isNotEmpty) {
        _strokes.removeLast();
      }
    });
  }

  void _onPanStart(DragStartDetails details, RenderBox box) {
    final position = box.globalToLocal(details.globalPosition);
    setState(() {
      _strokes.add([
        DrawPoint(
          position: position,
          color: _laserMode ? Colors.redAccent : _penColor,
          strokeWidth: _penSize,
        ),
      ]);
    });
  }

  void _onPanUpdate(DragUpdateDetails details, RenderBox box) {
    final position = box.globalToLocal(details.globalPosition);
    setState(() {
      if (_strokes.isEmpty) {
        _onPanStart(DragStartDetails(globalPosition: details.globalPosition), box);
        return;
      }
      _strokes.last.add(DrawPoint(
        position: position,
        color: _laserMode ? Colors.redAccent : _penColor,
        strokeWidth: _penSize,
      ));
    });
  }

  void _onPanEnd() {
    // End drawing gesture.
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: _seedColor));

    return MaterialApp(
      title: 'Reyaansh Notes',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: theme.colorScheme.primaryContainer),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reyaansh Notes', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('Quick actions', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.save),
                title: const Text('Export note'),
                onTap: () {
                  Navigator.of(context).pop();
                  _exportNote();
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Page settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showPageSettings(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.brush),
                title: const Text('Pick pen color'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickPenColor(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('Undo stroke'),
                onTap: () {
                  Navigator.of(context).pop();
                  _undoStroke();
                },
              ),
              ListTile(
                leading: const Icon(Icons.clear_all),
                title: const Text('Clear text'),
                onTap: () {
                  Navigator.of(context).pop();
                  _clearNoteText();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep),
                title: const Text('Clear drawing'),
                onTap: () {
                  Navigator.of(context).pop();
                  _clearDrawing();
                },
              ),
            ],
          ),
        ),
        appBar: AppBar(
          title: const Text('Reyaansh Notes'),
          actions: [
            IconButton(
              icon: const Icon(Icons.format_paint),
              tooltip: 'Theme color',
              onPressed: () => _pickThemeColor(context),
            ),
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Export',
              onPressed: _exportNote,
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Page settings',
              onPressed: () => _showPageSettings(context),
            ),
          ],
        ),
        body: Container(
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('Text mode'),
                    selected: !_isDrawMode,
                    onSelected: (_) {
                      setState(() {
                        _isDrawMode = false;
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Draw mode'),
                    selected: _isDrawMode,
                    onSelected: (selected) {
                      setState(() {
                        _isDrawMode = selected;
                      });
                    },
                  ),
                  ActionChip(
                    label: Text('Laser ${_laserMode ? 'On' : 'Off'}'),
                    avatar: Icon(_laserMode ? Icons.bolt : Icons.bolt_outlined),
                    onPressed: () {
                      setState(() {
                        _laserMode = !_laserMode;
                      });
                    },
                  ),
                  ActionChip(
                    label: const Text('Pen color'),
                    avatar: CircleAvatar(backgroundColor: _penColor, radius: 10),
                    onPressed: () => _pickPenColor(context),
                  ),
                  ActionChip(
                    label: Text('Pen size ${_penSize.toStringAsFixed(1)}'),
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (dialogContext) {
                          return AlertDialog(
                            title: const Text('Pen size'),
                            content: Slider(
                              value: _penSize,
                              min: 1,
                              max: 20,
                              divisions: 19,
                              label: _penSize.toStringAsFixed(1),
                              onChanged: (value) => setState(() => _penSize = value),
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
                    },
                  ),
                  ActionChip(
                    label: const Text('Add image'),
                    avatar: const Icon(Icons.image),
                    onPressed: _addImage,
                  ),
                  ActionChip(
                    label: const Text('Undo'),
                    avatar: const Icon(Icons.undo),
                    onPressed: _undoStroke,
                  ),
                  ActionChip(
                    label: const Text('Clear text'),
                    avatar: const Icon(Icons.clear_all),
                    onPressed: _clearNoteText,
                  ),
                  ActionChip(
                    label: const Text('Clear draw'),
                    avatar: const Icon(Icons.delete_sweep),
                    onPressed: _clearDrawing,
                  ),
                  ActionChip(
                    label: const Text('Publish'),
                    avatar: const Icon(Icons.cloud_upload),
                    onPressed: _publishNoteToFirebase,
                  ),
                  ActionChip(
                    label: Text(_softPen ? 'Soft pen' : 'Hard pen'),
                    avatar: Icon(_softPen ? Icons.blur_on : Icons.brush),
                    onPressed: () {
                      setState(() {
                        _softPen = !_softPen;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _pageColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        NoteTemplatePainterWidget(
                          template: _templateStyle,
                          pageColor: _pageColor,
                        ),
                        if (_isDrawMode)
                          Positioned.fill(
                            child: GestureDetector(
                              onPanStart: (details) {
                                final box = context.findRenderObject() as RenderBox;
                                _onPanStart(details, box);
                              },
                              onPanUpdate: (details) {
                                final box = context.findRenderObject() as RenderBox;
                                _onPanUpdate(details, box);
                              },
                              onPanEnd: (_) => _onPanEnd(),
                              child: CustomPaint(
                                painter: DrawingPainter(strokes: _strokes, softPen: _softPen, softRadius: _penSoftness),
                                child: Container(),
                              ),
                            ),
                          ),
                        if (!_isDrawMode)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SingleChildScrollView(
                              child: TextField(
                                controller: _noteController,
                                keyboardType: TextInputType.multiline,
                                maxLines: null,
                                decoration: const InputDecoration.collapsed(
                                  hintText: 'Write your note here...',
                                ),
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        if (_images.isNotEmpty)
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: _images.map((image) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: SizedBox(
                                    width: 100,
                                    height: 100,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(File(image.path), fit: BoxFit.cover),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoteTemplatePainterWidget extends StatelessWidget {
  const NoteTemplatePainterWidget({
    super.key,
    required this.template,
    required this.pageColor,
  });

  final NoteTemplateStyle template;
  final Color pageColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: NoteTemplatePainter(template: template, pageColor: pageColor),
      child: Container(),
    );
  }
}

enum NoteTemplateStyle { plain, english, hindi, maths }

class NoteTemplatePainter extends CustomPainter {
  NoteTemplatePainter({required this.template, required this.pageColor});

  final NoteTemplateStyle template;
  final Color pageColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = pageColor;
    canvas.drawRect(Offset.zero & size, paint);

    final linePaint = Paint()
      ..color = pageColor.computeLuminance() > 0.5 ? Colors.black26 : Colors.white30
      ..strokeWidth = 1;

    final marginPaint = Paint()
        ..color = template == NoteTemplateStyle.maths ? Colors.black12 : Colors.redAccent.withAlpha((0.6 * 255).round())
        ..strokeWidth = 2;

    switch (template) {
      case NoteTemplateStyle.plain:
        break;
      case NoteTemplateStyle.english:
        for (double y = 40; y < size.height; y += 36) {
          canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), linePaint);
        }
        break;
      case NoteTemplateStyle.hindi:
        for (double y = 40; y < size.height; y += 36) {
          canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), linePaint);
        }
        canvas.drawLine(Offset(16, size.height / 2), Offset(size.width - 16, size.height / 2), marginPaint);
        break;
      case NoteTemplateStyle.maths:
        for (double x = 16; x < size.width - 16; x += 24) {
          canvas.drawLine(Offset(x, 16), Offset(x, size.height - 16), linePaint);
        }
        for (double y = 16; y < size.height - 16; y += 24) {
          canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), linePaint);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant NoteTemplatePainter oldDelegate) {
    return oldDelegate.template != template || oldDelegate.pageColor != pageColor;
  }
}

class DrawPoint {
  DrawPoint({required this.position, required this.color, required this.strokeWidth});

  final Offset position;
  final Color color;
  final double strokeWidth;
}

class DrawingPainter extends CustomPainter {
  DrawingPainter({required this.strokes, this.softPen = true, this.softRadius = 2.0});

  final List<List<DrawPoint>> strokes;
  final bool softPen;
  final double softRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path();
      for (var i = 0; i < stroke.length; i++) {
        final point = stroke[i];
        if (i == 0) {
          path.moveTo(point.position.dx, point.position.dy);
        } else {
          path.lineTo(point.position.dx, point.position.dy);
        }
      }

      paint
        ..color = stroke.last.color.withAlpha(softPen ? 200 : 255)
        ..strokeWidth = stroke.last.strokeWidth
        ..maskFilter = softPen ? MaskFilter.blur(BlurStyle.normal, softRadius) : null;

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes || oldDelegate.softPen != softPen || oldDelegate.softRadius != softRadius;
  }
}

class NoteImage {
  NoteImage({required this.path, required this.offset, required this.scale});

  final String path;
  final Offset offset;
  final double scale;
}
