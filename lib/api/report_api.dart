import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/report.dart';

class ReportApi {
  static Future<String> uploadImage(File imageFile) async {
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance.ref().child(
      'report_images/$fileName.jpg',
    );
    final uploadTask = await ref.putFile(imageFile);
    return await uploadTask.ref.getDownloadURL();
  }

  static Future<void> submitReport(
    PoorLightingReport report,
    File imageFile,
  ) async {
    // Upload image and get URL
    final imageUrl = await uploadImage(imageFile);
    // Store report in Firestore
    await FirebaseFirestore.instance.collection('poor_lighting_reports').add({
      'description': report.description,
      'imageUrl': imageUrl,
      'latitude': report.latitude,
      'longitude': report.longitude,
      'timestamp': report.timestamp.toIso8601String(),
    });
  }

  static Future<List<PoorLightingReport>> fetchReports() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('poor_lighting_reports')
            .get();
    return snapshot.docs
        .map((doc) => PoorLightingReport.fromFirestore(doc.data()))
        .toList();
  }
}
