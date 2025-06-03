import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:geocoding/geocoding.dart';
import '../utils/location_utils.dart';
import '../api/report_api.dart';
import '../models/report.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/ml_utils.dart';
import '../utils/cloud_vision_utils.dart';
import '../utils/bounding_box_painter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart' show kIsWeb;
// For web file upload
import 'dart:html' as html;
import '../utils/image_upload_web.dart'
    if (dart.library.io) '../utils/image_upload_io.dart';
import 'dart:async';
import 'dart:math';

const String firebaseStorageBucket =
    'YOUR_FIREBASE_STORAGE_BUCKET.appspot.com'; // TODO: Replace with your bucket

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const double _demoLat = 14.5896;
  static const double _demoLng = 120.9811;
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  File? _image;
  html.File? _webImage;
  Position? _currentPosition;
  bool _isLoading = false;
  String placeName = '';
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _detectedObjects = [];
  LatLng? _pickedLatLng;
  final Random _random = Random();

  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<LocationPermission> _requestPermission() async {
    return (await Geolocator.requestPermission());
  }

  Future<double> calculateBrightness(
    File imageFile,
    Map<String, dynamic> boundingPoly,
  ) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return 0.0;

    final poly = boundingPoly['normalizedVertices'] as List;
    if (poly.length < 4) return 0.0;

    final xs =
        poly.map((v) => ((v['x'] ?? 0.0) * image.width).toInt()).toList();
    final ys =
        poly.map((v) => ((v['y'] ?? 0.0) * image.height).toInt()).toList();
    final left = xs.reduce((a, b) => a < b ? a : b);
    final right = xs.reduce((a, b) => a > b ? a : b);
    final top = ys.reduce((a, b) => a < b ? a : b);
    final bottom = ys.reduce((a, b) => a > b ? a : b);

    if (left >= right || top >= bottom) return 0.0;

    double sum = 0;
    int count = 0;
    for (int y = top; y < bottom; y++) {
      for (int x = left; x < right; x++) {
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;
          final brightness = (r + g + b) / 3.0;
          sum += brightness;
          count++;
        }
      }
    }
    return count > 0 ? sum / count : 0.0;
  }

  Future<Map<String, String>> getProvinceAndCityFromCoordinates(
    double lat,
    double lng,
  ) async {
    final placemarks = await placemarkFromCoordinates(lat, lng);
    if (placemarks.isNotEmpty) {
      final placemark = placemarks.first;
      return {
        'province': placemark.subAdministrativeArea ?? '',
        'city': placemark.locality ?? '',
      };
    }
    return {'province': '', 'city': ''};
  }

  Future<void> _getImage(ImageSource source) async {
    if (kIsWeb) {
      html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
      uploadInput.accept = 'image/*';
      uploadInput.click();
      uploadInput.onChange.listen((event) async {
        final files = uploadInput.files;
        if (files != null && files.isNotEmpty) {
          final file = files.first;
          setState(() {
            _webImage = file;
            _isLoading = true;
          });
          // Read bytes for analysis
          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);
          await reader.onLoad.first;
          final bytes = reader.result as List<int>;

          // Show loading indicator
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 16),
                  Text('Analyzing image...'),
                ],
              ),
              duration: Duration(seconds: 2),
            ),
          );

          // Use CloudVisionUtils to detect street lamp
          final objects = await CloudVisionUtils.detectObjects(bytes);
          print('Detected objects: $objects');

          final lightingLabels = [
            'lamp',
            'light',
            'streetlight',
            'street lamp',
            'street light',
            'lighting',
            'light fixture',
            'pole',
            'light pole',
            'post',
          ];

          final filteredObjects = <Map<String, dynamic>>[];
          for (final object in objects) {
            final name = object['name'].toString().toLowerCase();
            if (lightingLabels.any((lampLabel) => name.contains(lampLabel))) {
              // Brightness calculation for web skipped for now
              filteredObjects.add({...object, 'brightness': null});
            }
          }
          setState(() {
            _detectedObjects = filteredObjects;
            _isLoading = false;
          });

          final foundStreetLamp = objects.any(
            (object) => lightingLabels.any(
              (lampLabel) => object['name'].toLowerCase().contains(lampLabel),
            ),
          );

          if (foundStreetLamp) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Street lamp detected!'),
                  ],
                ),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No light source detected in the image. Describe the lighting conditions and any safety concerns',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      });
      return;
    }
    // Mobile/desktop
    var status = await Permission.photos.status;
    if (!status.isGranted) {
      status = await Permission.photos.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission to access images is required.'),
          ),
        );
        return;
      }
    }
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });

        // Show loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Analyzing image...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );

        // Use CloudVisionUtils to detect street lamp
        final objects = await CloudVisionUtils.detectObjects(_image!);
        print('Detected objects: $objects');

        final lightingLabels = [
          'lamp',
          'light',
          'streetlight',
          'street lamp',
          'street light',
          'lighting',
          'light fixture',
          'pole',
          'light pole',
          'post',
        ];

        final filteredObjects = <Map<String, dynamic>>[];
        for (final object in objects) {
          final name = object['name'].toString().toLowerCase();
          if (lightingLabels.any((lampLabel) => name.contains(lampLabel))) {
            final brightness = await calculateBrightness(
              _image!,
              object['boundingPoly'],
            );
            filteredObjects.add({...object, 'brightness': brightness});
          }
        }
        setState(() {
          _detectedObjects = filteredObjects;
        });

        final foundStreetLamp = objects.any(
          (object) => [
            'lamp',
            'light',
            'streetlight',
            'street lamp',
            'street light',
            'lighting',
            'light fixture',
            'pole',
            'light pole',
            'post',
          ].any(
            (lampLabel) => object['name'].toLowerCase().contains(lampLabel),
          ),
        );

        if (foundStreetLamp) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Street lamp detected!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No light source detected in the image. Describe the lighting conditions and any safety concerns',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('[ReportScreen] Error picking/analyzing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      if (kIsWeb) {
        // For web, we'll use the browser's geolocation API
        final position = await _getWebLocation();
        setState(() {
          _currentPosition = position;
          _pickedLatLng = LatLng(position.latitude, position.longitude);
        });
      } else {
        // For mobile
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied')),
            );
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied'),
            ),
          );
          return;
        }

        final position = await Geolocator.getCurrentPosition();
        setState(() {
          _currentPosition = position;
          _pickedLatLng = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Position> _getWebLocation() async {
    try {
      final completer = Completer<Position>();
      html.window.navigator.geolocation
          .getCurrentPosition()
          .then((position) {
            completer.complete(
              Position(
                latitude: (position.coords?.latitude ?? 0).toDouble(),
                longitude: (position.coords?.longitude ?? 0).toDouble(),
                timestamp: DateTime.now(),
                accuracy: (position.coords?.accuracy ?? 0).toDouble(),
                altitude: (position.coords?.altitude ?? 0).toDouble(),
                heading: (position.coords?.heading ?? 0).toDouble(),
                speed: (position.coords?.speed ?? 0).toDouble(),
                speedAccuracy: 0.0,
                altitudeAccuracy: 0.0,
                headingAccuracy: 0.0,
              ),
            );
          })
          .catchError((error) {
            completer.completeError(error);
          });
      return completer.future;
    } catch (e) {
      throw Exception('Failed to get web location: $e');
    }
  }

  Future<void> _pickLocationOnMap() async {
    // For demo: set a fake location (e.g., Manila City Hall)
    setState(() {
      _pickedLatLng = const LatLng(14.5896, 120.9811);
      _currentPosition = Position(
        latitude: 14.5896,
        longitude: 120.9811,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location set to Manila City Hall (demo)')),
    );
  }

  // Helper to randomize location by up to ~300 meters
  Map<String, double> _randomizedDemoLocation() {
    // 0.001 degree is roughly 111 meters
    double latOffset = (_random.nextDouble() - 0.5) * 0.003; // ±0.0015
    double lngOffset = (_random.nextDouble() - 0.5) * 0.003; // ±0.0015
    return {'lat': _demoLat + latOffset, 'lng': _demoLng + lngOffset};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Poor Lighting'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Instruction Card
              Card(
                color: Colors.yellow[50],
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amber[700], size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Light up the city!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Upload a photo of a dark spot. We'll analyze it and send it to our live database for real action. Your report helps make our streets safer!",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Image Section
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (kIsWeb && _webImage != null) ...[
                        Text('Selected: \\${_webImage!.name}'),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child:
                              _detectedObjects.isNotEmpty
                                  ? SizedBox(
                                    width: 300,
                                    height: 200,
                                    child: _WebImageWithBoxes(
                                      webImage: _webImage!,
                                      objects: _detectedObjects,
                                    ),
                                  )
                                  : Image.network(
                                    html.Url.createObjectUrl(_webImage!),
                                    height: 200,
                                    width: 300,
                                    fit: BoxFit.cover,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Note: The web version uses a limited Google Cloud Vision model. It may not detect streetlamps or lights. For best results, use the mobile app. See below for a demo of how the real model works.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/cv_demo.png',
                            width: 300,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Demo: This is how the mobile app detects and highlights streetlamps.',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ] else if (_image != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child:
                              _detectedObjects.isNotEmpty
                                  ? ImageWithBoxes(
                                    imageFile: _image!,
                                    objects: _detectedObjects,
                                  )
                                  : Image.file(
                                    _image!,
                                    height: 200,
                                    width: 300,
                                    fit: BoxFit.cover,
                                  ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _getImage(ImageSource.camera),
                              icon: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                              ),
                              label: const Text('Take Photo'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _getImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Gallery'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Location Section
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.location_on, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text(
                            'Location',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Always show demo location
                      Row(
                        children: const [
                          Icon(
                            Icons.location_city,
                            color: Colors.blueGrey,
                            size: 20,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'City: Manila',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 0.0, top: 2),
                        child: Row(
                          children: const [
                            Icon(Icons.map, color: Colors.green, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Province: Metro Manila',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 0.0, top: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.pin_drop,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _currentPosition != null
                                  ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}'
                                  : 'Lat: 14.5896, Lng: 120.9811',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Note: Demo location is always Manila City Hall.',
                      ),
                    ],
                  ),
                ),
              ),
              // Description Section
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.description, color: Colors.blueGrey),
                          SizedBox(width: 8),
                          Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText:
                              'Describe the lighting conditions and any safety concerns',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              // Submit Button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send, color: Colors.white),
                  label:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Submit Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      if ((kIsWeb && _webImage == null) ||
                          (!kIsWeb && _image == null)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please take or select a photo'),
                          ),
                        );
                        return;
                      }
                      // Always use randomized demo location
                      final loc = _randomizedDemoLocation();
                      final demoPosition = Position(
                        latitude: loc['lat']!,
                        longitude: loc['lng']!,
                        timestamp: DateTime.now(),
                        accuracy: 1.0,
                        altitude: 0.0,
                        heading: 0.0,
                        speed: 0.0,
                        speedAccuracy: 0.0,
                        altitudeAccuracy: 1.0,
                        headingAccuracy: 1.0,
                      );
                      setState(() {
                        _currentPosition = demoPosition;
                      });
                      setState(() => _isLoading = true);
                      try {
                        print('Creating report object...');
                        String imageUrl = '';
                        if (kIsWeb) {
                          imageUrl = await uploadImagePlatformWeb(
                            _webImage!,
                            firebaseStorageBucket,
                          );
                        } else {
                          imageUrl = await ReportApi.uploadImage(_image!);
                        }
                        final report = PoorLightingReport(
                          description: _descriptionController.text,
                          imageUrl: imageUrl,
                          latitude: _currentPosition!.latitude,
                          longitude: _currentPosition!.longitude,
                          timestamp: DateTime.now(),
                        );
                        print('Calling submitReport...');
                        await FirebaseFirestore.instance
                            .collection('poor_lighting_reports')
                            .add(report.toMap());
                        print('Report submitted!');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Report submitted!')),
                        );
                        setState(() {
                          _image = null;
                          _webImage = null;
                          _currentPosition = null;
                          _pickedLatLng = null;
                          _descriptionController.clear();
                        });
                      } catch (e, stack) {
                        print('Submission error: $e');
                        print('Stack trace: $stack');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to submit report: $e'),
                          ),
                        );
                      } finally {
                        setState(() => _isLoading = false);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}

class ImageWithBoxes extends StatelessWidget {
  final dynamic imageFile; // Can be File or html.File
  final List<Map<String, dynamic>> objects;

  const ImageWithBoxes({
    required this.imageFile,
    required this.objects,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Size>(
      future: _getImageSize(imageFile),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final imageSize = snapshot.data!;
        return Stack(
          children: [
            if (kIsWeb)
              Image.network(
                html.Url.createObjectUrl(imageFile),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            else
              Image.file(
                imageFile,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            Positioned.fill(
              child: CustomPaint(
                painter: BoundingBoxPainter(
                  objects,
                  imageSize.width,
                  imageSize.height,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Size> _getImageSize(dynamic file) async {
    if (kIsWeb) {
      final completer = Completer<Size>();
      final img = html.ImageElement();
      img.onLoad.listen((_) {
        completer.complete(Size(img.width!.toDouble(), img.height!.toDouble()));
      });
      img.src = html.Url.createObjectUrl(file);
      return completer.future;
    } else {
      final image = await decodeImageFromList(file.readAsBytesSync());
      return Size(image.width.toDouble(), image.height.toDouble());
    }
  }
}

class _WebImageWithBoxes extends StatelessWidget {
  final html.File webImage;
  final List<Map<String, dynamic>> objects;

  const _WebImageWithBoxes({
    required this.webImage,
    required this.objects,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Size>(
      future: _getImageSize(webImage),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final imageSize = snapshot.data!;
        return Stack(
          children: [
            Image.network(
              html.Url.createObjectUrl(webImage),
              height: 200,
              width: 300,
              fit: BoxFit.cover,
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: BoundingBoxPainter(
                  objects,
                  imageSize.width,
                  imageSize.height,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Size> _getImageSize(html.File file) async {
    final completer = Completer<Size>();
    final imgElem = html.ImageElement();
    imgElem.onLoad.listen((_) {
      completer.complete(
        Size(imgElem.width!.toDouble(), imgElem.height!.toDouble()),
      );
    });
    imgElem.src = html.Url.createObjectUrl(file);
    return completer.future;
  }
}
