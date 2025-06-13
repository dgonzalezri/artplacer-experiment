// main.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';

void main() {
  runApp(const WallArtApp());
}

class WallArtApp extends StatelessWidget {
  const WallArtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wall Art Placement PoC',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const WallArtEditor(),
    );
  }
}

// Add these classes for the frames and placed frames
class Frame {
  final String id;
  final String name;
  final double aspectRatio; // width/height
  final Size standardSize; // in cm
  
  const Frame({
    required this.id,
    required this.name,
    required this.aspectRatio,
    required this.standardSize,
  });
}

class PlacedFrame {
  final Frame frame;
  Offset position;
  double scale;
  Uint8List? imageBytes; 
  
  PlacedFrame({
    required this.frame,
    required this.position,
    this.scale = 1.0,
    this.imageBytes, 
  });
}

// Common frame sizes
const List<Frame> availableFrames = [
  Frame(
    id: 'a4',
    name: 'A4 (21×29.7cm)',
    aspectRatio: 21 / 29.7,
    standardSize: Size(21, 29.7),
  ),
  Frame(
    id: 'square_small',
    name: 'Square Small (20×20cm)',
    aspectRatio: 1.0,
    standardSize: Size(20, 20),
  ),
  Frame(
    id: 'landscape',
    name: 'Landscape (30×20cm)',
    aspectRatio: 30 / 20,
    standardSize: Size(30, 20),
  ),
  Frame(
    id: 'portrait',
    name: 'Portrait (20×30cm)',
    aspectRatio: 20 / 30,
    standardSize: Size(20, 30),
  ),
];

class WallArtEditor extends StatefulWidget {
  const WallArtEditor({super.key});

  @override
  State<WallArtEditor> createState() => _WallArtEditorState();
}

class _WallArtEditorState extends State<WallArtEditor> {
  File? backgroundImage;
  List<Offset> workAreaCorners = [];
  bool isDefiningWorkArea = false;
  Size? imageSize;
  Offset imageOffset = Offset.zero;
  List<PlacedFrame> placedFrames = [];
  List<double> workAreaSideLengths = [];
  String measurementUnit = 'cm';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wall Art Placement PoC'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _selectBackgroundImage,
                  child: const Text('Upload Background Image'),
                ),
                if (backgroundImageBytes != null)
                  ElevatedButton(
                    onPressed: _defineWorkArea,
                    child: const Text('Define Work Area'),
                  ),
                if (workAreaCorners.length == 4)
                  ElevatedButton(
                    onPressed: _showFrameSelector,
                    child: const Text('Add Frame'),
                  ),
              ],
            ),
          ),
          
          // Canvas Area
          Expanded(
            child: backgroundImageBytes == null
                ? const Center(
                    child: Text(
                      'Upload a background image to start',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : _buildCanvas(),
          ),
        ],
      ),
    );
  }

Uint8List? backgroundImageBytes;

Future<void> _selectBackgroundImage() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.image,
  );

  if (result != null) {
    setState(() {
      backgroundImageBytes = result.files.single.bytes;
    });
  }
}

  void _defineWorkArea() {
    setState(() {
      isDefiningWorkArea = true;
      workAreaCorners.clear();
    });
  }

  Widget _buildCanvas() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapDown: isDefiningWorkArea ? _onCanvasTap : null,
            child: Stack(
              children: [
                // Background image
                Center(
                  child: backgroundImageBytes != null ? Image.memory(backgroundImageBytes!, fit: BoxFit.contain) : const SizedBox(),
                ),
                
                // Work area overlay
                if (isDefiningWorkArea || workAreaCorners.isNotEmpty)
                  CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: WorkAreaPainter(
                      corners: workAreaCorners,
                      imageSize: imageSize,
                      imageOffset: imageOffset,
                    ),
                  ),
                
                // Placed frames
                ...placedFrames.map((placedFrame) => _buildPlacedFrame(placedFrame)),
                
                // Corner handles
                ...workAreaCorners.asMap().entries.map((entry) {
                  return Positioned(
                    left: entry.value.dx - 10,
                    top: entry.value.dy - 10,
                    child: _buildCornerHandle(entry.key),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCornerHandle(int index) {
    return GestureDetector(
      onPanUpdate: (details) => _updateCorner(index, details),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _onCanvasTap(TapDownDetails details) {
    if (workAreaCorners.length < 4) {
      setState(() {
        workAreaCorners.add(details.localPosition);
      });
      
      if (workAreaCorners.length == 4) {
        setState(() {
          isDefiningWorkArea = false;
        });
        _showWorkAreaDialog();
      }
    }
  }

  void _updateCorner(int index, DragUpdateDetails details) {
    setState(() {
      workAreaCorners[index] += details.delta;
    });
  }

  void _showWorkAreaDialog() {
    showDialog(
      context: context,
      builder: (context) => WorkAreaMeasurementsDialog(
        onMeasurementsSet: _setWorkAreaMeasurements,
      ),
    );
  }

  void _setWorkAreaMeasurements(List<double> sideLengths, String unit) {
    setState(() {
      workAreaSideLengths = sideLengths;
      measurementUnit = unit;
    });
  }

  void _showFrameSelector() {
    showDialog(
      context: context,
      builder: (context) => FrameSelectorDialog(
        frames: availableFrames,
        onFrameSelected: _addFrame,
      ),
    );
  }

  void _addFrame(Frame frame) {
    PlacedFrame newFrame = PlacedFrame(
      frame: frame,
      position: const Offset(100, 100),
      scale: 1.0,
    );
    
    setState(() {
      placedFrames.add(newFrame);
    });
  }

  Widget _buildPlacedFrame(PlacedFrame placedFrame) {

    double scale = _calculateFrameScale(placedFrame);
    double finalWidth = placedFrame.frame.standardSize.width * scale;
    double finalHeight = placedFrame.frame.standardSize.height * scale;
    
    print('=== RENDERING FRAME ===');
    print('Frame: ${placedFrame.frame.name}');
    print('Scale: $scale');
    print('Final container size: ${finalWidth.toStringAsFixed(1)} x ${finalHeight.toStringAsFixed(1)} pixels');
    print('Position: ${placedFrame.position}');
    print('=== END RENDER ===');

    return Positioned(
      left: placedFrame.position.dx,
      top: placedFrame.position.dy,
      child: GestureDetector(
        onTap: () => _selectImageForFrame(placedFrame),
        onPanUpdate: (details) => _updateFramePosition(placedFrame, details),
        child: Container(
          width: placedFrame.frame.standardSize.width * _calculateFrameScale(placedFrame),
          height: placedFrame.frame.standardSize.height * _calculateFrameScale(placedFrame),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.red, width: 4), // Thicker border
            color: Colors.yellow.withOpacity(0.3), // More visible background
                    ),
          child: placedFrame.imageBytes != null
              ? Image.memory(placedFrame.imageBytes!, fit: BoxFit.cover)
              : const Center(
                  child: Text(
                    'Tap to add image',
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ),
    );
  }

  void _updateFramePosition(PlacedFrame placedFrame, DragUpdateDetails details) {
    setState(() {
      placedFrame.position += details.delta;
    });
  }

  void _selectImageForFrame(PlacedFrame placedFrame) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        placedFrame.imageBytes = result.files.single.bytes!;
      });
    }
  }

  Future<File?> _cropImageToRatio(File image, double aspectRatio) async {
    // TODO: Implement image cropping to match frame aspect ratio
    // For now, return the original image
    return image;
  }

  double _calculateFrameScale(PlacedFrame placedFrame) {
    print('=== DEBUG: _calculateFrameScale ===');
    print('workAreaCorners.length: ${workAreaCorners.length}');
    print('workAreaSideLengths.length: ${workAreaSideLengths.length}');
    print('workAreaSideLengths: $workAreaSideLengths');
    print('measurementUnit: $measurementUnit');
    
    if (workAreaCorners.length != 4 || workAreaSideLengths.length != 4) {
      print('ERROR: Missing corners or measurements, returning default scale 1.0');
      return 1.0; // Default scale if measurements aren't complete
    }
    
    // Calculate pixel-to-real-world ratios for each side
    List<double> pixelDistances = [];
    for (int i = 0; i < 4; i++) {
      int nextIndex = (i + 1) % 4;
      double pixelDistance = (workAreaCorners[nextIndex] - workAreaCorners[i]).distance;
      pixelDistances.add(pixelDistance);
      print('Side $i: ${pixelDistance.toStringAsFixed(2)} pixels = ${workAreaSideLengths[i]} $measurementUnit');
    }
    
    // Calculate pixels per unit (cm/m/in/ft) for each side
    List<double> pixelsPerUnit = [];
    for (int i = 0; i < 4; i++) {
      double ratio = pixelDistances[i] / workAreaSideLengths[i];
      pixelsPerUnit.add(ratio);
      print('Side $i: ${ratio.toStringAsFixed(2)} pixels per $measurementUnit');
    }
    
    // Use average pixels per unit (you could make this more sophisticated based on frame position)
    double avgPixelsPerUnit = pixelsPerUnit.reduce((a, b) => a + b) / pixelsPerUnit.length;
    print('Average pixels per $measurementUnit: ${avgPixelsPerUnit.toStringAsFixed(2)}');
    
    // Convert frame size from cm to pixels
    double frameWidthInPixels = placedFrame.frame.standardSize.width * avgPixelsPerUnit;
    double frameHeightInPixels = placedFrame.frame.standardSize.height * avgPixelsPerUnit;
    
    print('Frame ${placedFrame.frame.name}:');
    print('  - Standard size: ${placedFrame.frame.standardSize.width} x ${placedFrame.frame.standardSize.height} cm');
    print('  - Calculated pixels: ${frameWidthInPixels.toStringAsFixed(2)} x ${frameHeightInPixels.toStringAsFixed(2)}');
    
    // Scale factor
    double scale = frameWidthInPixels / 100;
    print('Final scale factor: ${scale.toStringAsFixed(3)}');
    print('=== END DEBUG ===\n');
    
    return avgPixelsPerUnit;
  }

}

// Work Area Painter
class WorkAreaPainter extends CustomPainter {
  final List<Offset> corners;
  final Size? imageSize;
  final Offset imageOffset;

  WorkAreaPainter({
    required this.corners,
    this.imageSize,
    required this.imageOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length < 2) return;

    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.blue.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Draw lines between corners
    for (int i = 0; i < corners.length; i++) {
      final start = corners[i];
      final end = corners[(i + 1) % corners.length];
      
      if (i < corners.length - 1 || corners.length == 4) {
        canvas.drawLine(start, end, paint);
      }
    }

    // Fill the work area if we have 4 corners
    if (corners.length == 4) {
      final path = Path();
      path.moveTo(corners[0].dx, corners[0].dy);
      for (int i = 1; i < corners.length; i++) {
        path.lineTo(corners[i].dx, corners[i].dy);
      }
      path.close();
      canvas.drawPath(path, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class WorkAreaMeasurementsDialog extends StatefulWidget {
  final Function(List<double> sideLengths, String unit) onMeasurementsSet;
  
  const WorkAreaMeasurementsDialog({
    super.key,
    required this.onMeasurementsSet,
  });

  @override
  State<WorkAreaMeasurementsDialog> createState() => _WorkAreaMeasurementsDialogState();
}

class _WorkAreaMeasurementsDialogState extends State<WorkAreaMeasurementsDialog> {
  final List<TextEditingController> sideControllers = [
    TextEditingController(), // Top side
    TextEditingController(), // Right side
    TextEditingController(), // Bottom side
    TextEditingController(), // Left side
  ];
  String selectedUnit = 'cm';

  final List<String> sideLabels = [
    'Top side (1→2)',
    'Right side (2→3)', 
    'Bottom side (3→4)',
    'Left side (4→1)',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Wall Area Measurements'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the real-world length of each side:'),
            const SizedBox(height: 16),
            
            ...List.generate(4, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        sideLabels[index],
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: sideControllers[index],
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, 
                            vertical: 8,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (index == 0) // Only show unit dropdown on first row
                      DropdownButton<String>(
                        value: selectedUnit,
                        items: ['cm', 'm', 'in', 'ft'].map((unit) {
                          return DropdownMenuItem(value: unit, child: Text(unit));
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedUnit = value!;
                          });
                        },
                      )
                    else
                      Text(selectedUnit),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveMeasurements,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveMeasurements() {
    List<double> sideLengths = [];
    
    for (int i = 0; i < 4; i++) {
      final length = double.tryParse(sideControllers[i].text);
      if (length == null || length <= 0) {
        // Show error for invalid input
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid length for ${sideLabels[i]}')),
        );
        return;
      }
      sideLengths.add(length);
    }
    
    widget.onMeasurementsSet(sideLengths, selectedUnit);
    Navigator.of(context).pop();
  }
}

// Frame Selector Dialog
class FrameSelectorDialog extends StatelessWidget {
  final List<Frame> frames;
  final Function(Frame) onFrameSelected;
  
  const FrameSelectorDialog({
    super.key,
    required this.frames,
    required this.onFrameSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Frame Size'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: ListView.builder(
          itemCount: frames.length,
          itemBuilder: (context, index) {
            final frame = frames[index];
            return ListTile(
              title: Text(frame.name),
              subtitle: Text('Ratio: ${frame.aspectRatio.toStringAsFixed(2)}'),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: AspectRatio(
                  aspectRatio: frame.aspectRatio,
                  child: Container(
                    color: Colors.blue.withOpacity(0.2),
                  ),
                ),
              ),
              onTap: () {
                onFrameSelected(frame);
                Navigator.of(context).pop();
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}