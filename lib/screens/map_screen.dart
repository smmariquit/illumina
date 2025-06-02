import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/location_utils.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

Future<LocationPermission> _requestPermission() async {
  return (await Geolocator.requestPermission());
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  LocationPermission? _permissionStatus;
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _requestPermission();
    getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Map'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target:
                  _currentPosition ??
                  const LatLng(14.5995, 120.9842), // Manila, Philippines
              zoom: 12,
            ),
            onMapCreated: (GoogleMapController controller) {
              _controller = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: MapType.normal,
            zoomControlsEnabled: true,
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
