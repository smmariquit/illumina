// Only import firebase.dart on web
// ignore: uri_does_not_exist
import 'package:firebase/firebase.dart' as fb;
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
// import 'package:http/http.dart' as http;
import 'dart:io' show File; // For type compatibility, but not used on web

// NOTE: Make sure to add 'firebase' as a dependency in your pubspec.yaml for web support.
// See: https://pub.dev/packages/firebase

Future<String> uploadImagePlatform(File file) async {
  // This function is only called on web, so file is actually a html.File
  // But for compatibility, we expect a File, so we throw if not web
  throw UnsupportedError('Use html.File for web uploads');
}

Future<String> uploadImagePlatformWeb(
  html.File file,
  String firebaseStorageBucket,
) async {
  try {
    // Initialize Firebase app if not already initialized
    if (fb.apps.isEmpty) {
      fb.initializeApp(
        apiKey: "AIzaSyDnXdm-YHLdQS-8E0Hnmfgg5E0TClOkiiE",
        authDomain: "illumina-spark-pup.firebaseapp.com",
        projectId: "illumina-spark-pup",
        storageBucket: "illumina-spark-pup.appspot.com",
        messagingSenderId: "560333200922",
        appId: "1:560333200922:web:b9d826cc91a0ae4b137ba3",
        measurementId: "G-1DQ4B8E02Z",
      );
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'reports/$timestamp-${file.name}';
    final storageRef = fb.storage().ref(fileName);
    final uploadTask = storageRef.put(file);
    await uploadTask.future;
    final url = await storageRef.getDownloadURL();
    return url.toString();
  } catch (e, stack) {
    // Log error to console for debugging
    print('[WebUpload] Error uploading image: $e');
    print(stack);
    throw Exception('Failed to upload image to Firebase Storage (web): $e');
  }
}
