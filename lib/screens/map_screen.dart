import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../api/report_api.dart';
import '../models/report.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    final reports = await ReportApi.fetchReports();
    setState(() {
      _reports = reports;
      _markers =
          reports.map((report) {
            return Marker(
              markerId: MarkerId(report.timestamp.toIso8601String()),
              position: LatLng(report.latitude, report.longitude),
              onTap: () => _showReportDialog(report),
            );
          }).toSet();
      _loading = false;
    });
  }

  void _showReportDialog(PoorLightingReport report) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Poor Lighting Report'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.network(report.imageUrl, height: 150, fit: BoxFit.cover),
                const SizedBox(height: 8),
                Text(report.description),
                const SizedBox(height: 8),
                Text('Lat: \\${report.latitude.toStringAsFixed(6)}'),
                Text('Lng: \\${report.longitude.toStringAsFixed(6)}'),
                Text('Time: \\${report.timestamp}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Map'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(37.7749, -122.4194),
                      zoom: 12,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      _controller = controller;
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    mapType: MapType.normal,
                    zoomControlsEnabled: true,
                    markers: _markers,
                  ),
                  // Floating action buttons for quick actions
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton(
                          onPressed: () {
                            // TODO: Implement check-in timer
                          },
                          child: const Icon(Icons.timer),
                        ),
                        const SizedBox(height: 16),
                        FloatingActionButton(
                          onPressed: () {
                            // TODO: Implement passing through alert
                          },
                          child: const Icon(Icons.warning),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
