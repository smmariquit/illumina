import 'package:cloud_firestore/cloud_firestore.dart';

class PoorLightingReport {
  final String description;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final List<Map<String, dynamic>>? detectedObjects;

  PoorLightingReport({
    required this.description,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.detectedObjects,
  });

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'detectedObjects': detectedObjects,
    };
  }

  factory PoorLightingReport.fromMap(Map<String, dynamic> map) {
    return PoorLightingReport(
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      detectedObjects: List<Map<String, dynamic>>.from(
        map['detectedObjects'] ?? [],
      ),
    );
  }

  factory PoorLightingReport.fromFirestore(Map<String, dynamic> data) {
    return PoorLightingReport(
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(
        data['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      detectedObjects: data['detectedObjects'] as List<Map<String, dynamic>>?,
    );
  }
}
