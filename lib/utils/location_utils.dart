import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

Future<Position?> getCurrentPosition() async {
  try {
    return await Geolocator.getCurrentPosition();
  } catch (e) {
    return null;
  }
}

Future<String> getPlaceFromCoordinates(
  double latitude,
  double longitude,
) async {
  try {
    final placemarks = await placemarkFromCoordinates(latitude, longitude);
    return placemarks.first.toString();
  } catch (e) {
    return 'Error: $e';
  }
}
