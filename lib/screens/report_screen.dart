import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import '../utils/location_utils.dart';
import '../api/report_api.dart';
import '../models/report.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

Future<LocationPermission> _requestPermission() async {
  return (await Geolocator.requestPermission());
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  File? _image;
  Position? _currentPosition;
  bool _isLoading = false;
  String placeName = '';
  final ImagePicker _picker = ImagePicker();

  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _getImage(ImageSource source) async {
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
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to pick image')));
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
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

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
              // Image Preview
              if (_image != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _image!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Image Capture Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _getImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _getImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Location Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_currentPosition != null)
                        FutureBuilder<String>(
                          future: getPlaceFromCoordinates(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Text('Loading place...');
                            } else if (snapshot.hasError) {
                              return Text('Error loading place');
                            } else if (snapshot.hasData) {
                              return Text(
                                'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}\n'
                                'Long: ${_currentPosition!.longitude.toStringAsFixed(6)}\n'
                                'Place: ${snapshot.data}',
                                style: const TextStyle(color: Colors.grey),
                              );
                            } else {
                              return const SizedBox(height: 8);
                            }
                          },
                        )
                      else
                        const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _getCurrentLocation,
                        icon:
                            _isLoading
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.location_on),
                        label: Text(
                          _isLoading
                              ? 'Getting Location...'
                              : 'Get Current Location',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description of Poor Lighting',
                  hintText:
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
              const SizedBox(height: 16),

              // Submit Button
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    if (_image == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please take or select a photo'),
                        ),
                      );
                      return;
                    }
                    if (_currentPosition == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please get your current location'),
                        ),
                      );
                      return;
                    }
                    setState(() => _isLoading = true);
                    try {
                      final report = PoorLightingReport(
                        description: _descriptionController.text,
                        imagePath: _image!.path,
                        latitude: _currentPosition!.latitude,
                        longitude: _currentPosition!.longitude,
                        timestamp: DateTime.now(),
                      );
                      await ReportApi.submitReport(report, _image!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Report submitted!')),
                      );
                      setState(() {
                        _image = null;
                        _currentPosition = null;
                        _descriptionController.clear();
                      });
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to submit report: \\${e.toString()}',
                          ),
                        ),
                      );
                    } finally {
                      setState(() => _isLoading = false);
                    }
                  }
                },
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Submit Report'),
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
