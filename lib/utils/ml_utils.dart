import 'dart:io';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class MLUtils {
  static ObjectDetector? _objectDetector;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    try {
      print('\n[MLUtils] Initializing Object Detector...');
      _objectDetector = ObjectDetector(
        options: ObjectDetectorOptions(
          mode: DetectionMode.stream,
          classifyObjects: true,
          multipleObjects: true,
        ),
      );
      _isInitialized = true;
      print('[MLUtils] ✅ Object Detector initialized successfully');
    } catch (e) {
      print('[MLUtils] ❌ Error initializing Object Detector: $e');
      _isInitialized = false;
    }
  }

  static Future<bool> detectStreetLamp(File imageFile) async {
    try {
      if (!_isInitialized) {
        print(
          '[MLUtils] ⚠️ Object Detector not initialized. Initializing now...',
        );
        await initialize();
        if (!_isInitialized) {
          print('[MLUtils] ❌ Failed to initialize Object Detector');
          return false;
        }
      }

      print('\n[MLUtils] ===== Starting Object Detection =====');
      print('[MLUtils] Image path: ${imageFile.path}');
      print('[MLUtils] Image exists: ${await imageFile.exists()}');
      print('[MLUtils] Image size: ${await imageFile.length()} bytes');

      final inputImage = InputImage.fromFile(imageFile);
      print('[MLUtils] Input image created successfully');

      if (_objectDetector == null) {
        print('[MLUtils] ❌ Object Detector is null');
        return false;
      }

      print('[MLUtils] Processing image...');
      final List<DetectedObject> objects = await _objectDetector!.processImage(
        inputImage,
      );

      print('\n[MLUtils] 🔍 DETECTION RESULTS');
      print('[MLUtils] ========================================');
      print('[MLUtils] Total objects found: ${objects.length}');
      print('[MLUtils] ========================================\n');

      // First, print ALL detected objects and their labels
      print('[MLUtils] 📋 COMPLETE DETECTION LIST:');
      print('[MLUtils] ========================================');
      for (int i = 0; i < objects.length; i++) {
        final object = objects[i];
        print('\n[MLUtils] Object #${i + 1}:');
        print('[MLUtils] - Bounding Box: ${object.boundingBox}');
        print('[MLUtils] - All Labels:');

        // Sort labels by confidence
        final sortedLabels =
            object.labels.toList()
              ..sort((a, b) => b.confidence.compareTo(a.confidence));

        for (var label in sortedLabels) {
          print(
            '[MLUtils]   * ${label.text} (${(label.confidence * 100).toStringAsFixed(1)}%)',
          );
        }
        print('[MLUtils] ----------------------------------------');
      }
      print('[MLUtils] ========================================\n');

      // Then check for street lamp related labels
      print('[MLUtils] 🔦 STREET LAMP DETECTION:');
      print('[MLUtils] ========================================');
      print('[MLUtils] Looking for: ${streetLampLabels.join(", ")}');
      print('[MLUtils] ----------------------------------------');

      bool foundStreetLamp = false;
      for (DetectedObject object in objects) {
        for (var label in object.labels) {
          if (streetLampLabels.any(
            (lampLabel) =>
                label.text.toLowerCase().contains(lampLabel.toLowerCase()),
          )) {
            foundStreetLamp = true;
            print('[MLUtils] ✅ Found potential street lamp:');
            print('[MLUtils] - Label: ${label.text}');
            print(
              '[MLUtils] - Confidence: ${(label.confidence * 100).toStringAsFixed(1)}%',
            );
            print('[MLUtils] - Location: ${object.boundingBox}');
          }
        }
      }

      if (!foundStreetLamp) {
        print('[MLUtils] ❌ No street lamp related objects found');
      }
      print('[MLUtils] ========================================\n');
      return foundStreetLamp;
    } catch (e, stackTrace) {
      print('\n[MLUtils] ❌ Error during object detection: $e');
      print('[MLUtils] Stack trace: $stackTrace');
      print('[MLUtils] ========================================\n');
      return false;
    }
  }

  static final List<String> streetLampLabels = [
    'lamp',
    'light',
    'streetlight',
    'street lamp',
    'street light',
    'lighting',
    'light fixture',
    'pole',
    'street pole',
    'light pole',
    'post',
    'street post',
    'light post',
  ];

  static void dispose() {
    _objectDetector?.close();
    _isInitialized = false;
  }
}
