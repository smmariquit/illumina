import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../api/report_api.dart';
import '../models/report.dart';
import 'package:geocoding/geocoding.dart';
import '../utils/bounding_box_painter.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:html' as html;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  List<PoorLightingReport> _reports = [];
  Set<Marker> _markers = {};
  bool _loading = true;
  bool _mapCreated = false;
  Map<String, Widget> _markerOverlays = {};
  bool _isDialogOpen = false;

  @override
  void initState() {
    super.initState();
    print('[MapScreen] initState called');
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    try {
      print('[MapScreen] Fetching reports...');
      final reports = await ReportApi.fetchReports();
      print('[MapScreen] Fetched ${reports.length} reports');

      if (reports.isEmpty) {
        print('[MapScreen] No reports found');
        setState(() {
          _loading = false;
        });
        return;
      }

      setState(() {
        _reports = reports;
        _markers =
            reports.map((report) {
              return Marker(
                markerId: MarkerId(report.timestamp.toIso8601String()),
                position: LatLng(report.latitude, report.longitude),
                infoWindow: InfoWindow(
                  title: 'Poor Lighting Report',
                  snippet: report.description,
                ),
                onTap: () => _showReportDetails(report),
              );
            }).toSet();
        _loading = false;
      });
    } catch (e) {
      print('[MapScreen] Error fetching reports: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    setState(() {
      _mapCreated = true;
    });
  }

  Future<Map<String, String>> getProvinceAndCityFromCoordinates(
    double lat,
    double lng,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return {
          'province': placemark.subAdministrativeArea ?? '',
          'city': placemark.locality ?? '',
        };
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return {'province': '', 'city': ''};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Poor Lighting Map')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'emergency',
            onPressed: _showEmergencyCallDialog,
            backgroundColor: Colors.red,
            child: const Icon(Icons.call),
            tooltip: 'Emergency Call',
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'risky',
            onPressed: _showRiskyAreaPopup,
            child: const Icon(Icons.warning_amber_rounded),
            backgroundColor: Colors.orange,
            tooltip: 'Demo: Show Risky Area Popup',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(14.3262013, 121.0903658), // Default to a location
              zoom: 12,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            mapToolbarEnabled: true,
            mapType: MapType.normal,
            onTap: (_) {
              setState(() {
                _markers =
                    _markers.map((marker) {
                      return Marker(
                        markerId: marker.markerId,
                        position: marker.position,
                        infoWindow: InfoWindow(
                          title: marker.infoWindow.title,
                          snippet: marker.infoWindow.snippet,
                        ),
                      );
                    }).toSet();
              });
            },
          ),
          if (_isDialogOpen)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(color: Colors.transparent),
              ),
            ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          // Background monitoring banner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Center(
                child: Text(
                  'Background monitoring active',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          // Notification bar for low lighting
          if (_showLowLightingBanner)
            Positioned(
              top: 36,
              left: 0,
              right: 0,
              child: Container(
                width: double.infinity,
                color: Colors.yellow[100],
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Low lighting detected in your area',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'You are about to enter a risky, poorly-lit area. Stay alert.',
                    ),
                  ],
                ),
              ),
            ),
          // Action buttons for passing through and reporting hazard
          Positioned(
            top: 64,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _showRiskyAreaPopup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        textStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'PASSING THROUGH',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/report');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        textStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'REPORT HAZARD',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 1),
                              blurRadius: 2,
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
        ],
      ),
    );
  }

  Future<dynamic> _getImageFile(String imageUrl) async {
    if (kIsWeb) {
      // For web, just return the URL string
      return imageUrl;
    }
    final response = await http.get(Uri.parse(imageUrl));
    final tempDir = await Directory.systemTemp.createTemp();
    final file = File('${tempDir.path}/temp_image.jpg');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  void _showReportDetails(PoorLightingReport report) async {
    if (_isDialogOpen) {
      // Prevent opening multiple dialogs
      return;
    }
    String city = '';
    String province = '';
    try {
      final location = await getProvinceAndCityFromCoordinates(
        report.latitude,
        report.longitude,
      );
      city = location['city'] ?? '';
      province = location['province'] ?? '';
    } catch (e) {
      print('Error getting location details: $e');
    }
    setState(() {
      _isDialogOpen = true;
    });
    try {
      await showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Report Details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<dynamic>(
                      future: _getImageFile(report.imageUrl),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Container(
                            height: 200,
                            width: 300,
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return Container(
                            height: 200,
                            width: 300,
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.error_outline, size: 50),
                            ),
                          );
                        }

                        final imageData = snapshot.data;
                        if (imageData == null ||
                            (imageData is String && imageData.isEmpty)) {
                          return Container(
                            height: 200,
                            width: 300,
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.broken_image, size: 50),
                            ),
                          );
                        }
                        final detectedObjects = report.detectedObjects ?? [];

                        if (detectedObjects.isEmpty) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child:
                                kIsWeb
                                    ? Image.network(
                                      imageData,
                                      height: 200,
                                      width: 300,
                                      fit: BoxFit.cover,
                                    )
                                    : Image.file(
                                      imageData,
                                      height: 200,
                                      width: 300,
                                      fit: BoxFit.cover,
                                    ),
                          );
                        }

                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 200,
                            width: 300,
                            child: ImageWithBoxes(
                              imageData: imageData,
                              objects: detectedObjects,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Description:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(report.description),
                    const SizedBox(height: 16),
                    const Text(
                      'Location:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (city.isNotEmpty)
                      Text('City: $city', style: const TextStyle(fontSize: 15)),
                    if (province.isNotEmpty)
                      Text(
                        'Province: $province',
                        style: const TextStyle(fontSize: 15),
                      ),
                    Text('Latitude: ${report.latitude.toStringAsFixed(6)}'),
                    Text('Longitude: ${report.longitude.toStringAsFixed(6)}'),
                    const SizedBox(height: 16),
                    const Text(
                      'Reported:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${report.timestamp.day}/${report.timestamp.month}/${report.timestamp.year} at ${report.timestamp.hour}:${report.timestamp.minute.toString().padLeft(2, '0')}',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDialogOpen = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // Add state for low lighting banner
  bool get _showLowLightingBanner => false; // Set to true to show the banner

  void _showRiskyAreaPopup() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Risky Area!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text('Notified contacts:'),
                const SizedBox(height: 8),
                // Dummy contacts
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircleAvatar(
                      backgroundImage: AssetImage('assets/lux.png'),
                      radius: 18,
                    ),
                    SizedBox(width: 8),
                    CircleAvatar(
                      backgroundImage: AssetImage('assets/sdg11.png'),
                      radius: 18,
                    ),
                    SizedBox(width: 8),
                    CircleAvatar(
                      backgroundImage: AssetImage('assets/sdg16.png'),
                      radius: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed:
                      () => Navigator.of(context, rootNavigator: true).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
    );
  }

  void _showEmergencyCallDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Emergency Call'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.call, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('Call emergency services or a contact?'),
                const SizedBox(height: 16),
                // Call 911
                ElevatedButton.icon(
                  icon: const Icon(Icons.call),
                  label: const Text('Call 911'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    // In production, use url_launcher to dial 911
                  },
                ),
                const SizedBox(height: 8),
                // Dummy contacts
                ElevatedButton.icon(
                  icon: const Icon(Icons.call),
                  label: const Text('Call Daniel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                  ),
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    // In production, use url_launcher to dial Daniel
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.call),
                  label: const Text('Call Juliane'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                  ),
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    // In production, use url_launcher to dial Juliane
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.call),
                  label: const Text('Call Simone'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                  ),
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    // In production, use url_launcher to dial Simone
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed:
                    () => Navigator.of(context, rootNavigator: true).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }
}

class ImageWithBoxes extends StatelessWidget {
  final dynamic imageData; // Can be File or String (URL)
  final List<Map<String, dynamic>> objects;

  const ImageWithBoxes({
    required this.imageData,
    required this.objects,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Size>(
      future: _getImageSize(imageData),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final imageSize = snapshot.data!;
        return Stack(
          children: [
            if (kIsWeb)
              Image.network(
                imageData,
                height: 200,
                width: 300,
                fit: BoxFit.cover,
              )
            else
              Image.file(imageData, height: 200, width: 300, fit: BoxFit.cover),
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

  Future<Size> _getImageSize(dynamic data) async {
    if (kIsWeb) {
      final completer = Completer<Size>();
      final img = html.ImageElement();
      img.onLoad.listen((_) {
        completer.complete(Size(img.width!.toDouble(), img.height!.toDouble()));
      });
      img.src = data;
      return completer.future;
    } else {
      final image = await decodeImageFromList(data.readAsBytesSync());
      return Size(image.width.toDouble(), image.height.toDouble());
    }
  }
}
