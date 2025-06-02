class PoorLightingReport {
  final String description;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  PoorLightingReport({
    required this.description,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory PoorLightingReport.fromFirestore(Map<String, dynamic> data) {
    return PoorLightingReport(
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(
        data['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
