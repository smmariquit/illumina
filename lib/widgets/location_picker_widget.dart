import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationPickerWidget extends StatefulWidget {
  final void Function(Position?) onLocationSelected;
  const LocationPickerWidget({super.key, required this.onLocationSelected});

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  Position? _position;
  bool _isLoading = false;

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _position = position;
      });
      widget.onLocationSelected(_position);
    } catch (e) {
      widget.onLocationSelected(null);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_position != null)
          Text('Lat: \\${_position!.latitude}, Lng: \\${_position!.longitude}'),
        ElevatedButton(
          onPressed: _isLoading ? null : _getCurrentLocation,
          child:
              _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Get Current Location'),
        ),
      ],
    );
  }
}
