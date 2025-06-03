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
        apiKey: 'YOUR_API_KEY',
        authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
        databaseURL: 'https://YOUR_PROJECT_ID.firebaseio.com',
        projectId: 'YOUR_PROJECT_ID',
        storageBucket: firebaseStorageBucket,
        messagingSenderId: 'YOUR_SENDER_ID',
        appId: 'YOUR_APP_ID',
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
