import 'dart:io';
import 'package:camera/camera.dart';
import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

late List<CameraDescription> cameras;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: CameraScreen());
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _cameraController;

  final List<String> _listOfString = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    await _cameraController.initialize();
    setState(() {});
  }

  Future<void> _onTakeImage() async {
    final Logger logger = Logger();
    try {
      _listOfString.clear();
      setState(() {});

      // Take Image
      XFile? xfile = await _cameraController.takePicture();
      final InputImage inputImage = InputImage.fromFilePath(xfile.path);

      // Define ML Model
      final ImageLabelerOptions options = ImageLabelerOptions(
        confidenceThreshold: 0.5,
      );
      final imageLabeler = ImageLabeler(options: options);

      // Process Image
      final List<ImageLabel> labels = await imageLabeler.processImage(
        inputImage,
      );

      for (ImageLabel label in labels) {
        final String text = label.label;
        final double confidence = label.confidence;
        logger.d('$text: ${(confidence * 100).toStringAsFixed(2)}%');
        _listOfString.add('$text: ${(confidence * 100).toStringAsFixed(2)}%');
      }
      setState(() {});

      imageLabeler.close();
    } catch (e) {
      logger.e(e.toString());
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _cameraController.value.isInitialized
          ? Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 16,
                  children: [
                    AspectRatio(
                      aspectRatio: _cameraController.value.aspectRatio,
                      child: CameraPreview(_cameraController),
                    ),
                    ElevatedButton(
                      onPressed: _onTakeImage,
                      child: Text("Take Photo"),
                    ),
                    SizedBox(
                      height: 400,
                      width: 300,
                      child: ListView.separated(
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 16),
                        itemCount: _listOfString.length,
                        itemBuilder: (context, index) => Text(
                          '${index + 1}. ${_listOfString[index]}',
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Center(child: CircularProgressIndicator()),
    );
  }
}
