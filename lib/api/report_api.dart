import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report.dart';
import '../utils/image_upload.dart';

class ReportApi {
  static Future<String> uploadImage(File file) async {
    // Use platform-specific implementation
    return uploadImagePlatform(file);
  }

  static Future<void> submitReport(
    PoorLightingReport report,
    File imageFile,
  ) async {
    print('[ReportApi] submitReport called');
    // Upload image and get URL
    final imageUrl = await uploadImage(imageFile);
    print('[ReportApi] Image uploaded, URL: $imageUrl');
    // Store report in Firestore
    print('[ReportApi] Adding report to Firestore...');
    await FirebaseFirestore.instance.collection('poor_lighting_reports').add({
      'description': report.description,
      'imageUrl': imageUrl,
      'latitude': report.latitude,
      'longitude': report.longitude,
      'timestamp': report.timestamp.toIso8601String(),
    });
    print('[ReportApi] Report added to Firestore!');
  }

  static Future<List<PoorLightingReport>> fetchReports() async {
    print('[ReportApi] fetchReports called');
    final snapshot =
        await FirebaseFirestore.instance
            .collection('poor_lighting_reports')
            .get();
    print('[ReportApi] fetchReports got snapshot');
    return snapshot.docs
        .map((doc) => PoorLightingReport.fromFirestore(doc.data()))
        .toList();
  }
}
