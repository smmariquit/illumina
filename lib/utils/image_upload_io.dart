import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

Future<String> uploadImagePlatform(File file) async {
  final storageRef = FirebaseStorage.instance.ref();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final imageRef = storageRef.child('reports/$timestamp.jpg');
  final metadata = SettableMetadata(
    contentType: 'image/jpeg',
    customMetadata: {'timestamp': timestamp.toString()},
  );
  final uploadTask = await imageRef.putFile(file, metadata);
  final downloadUrl = await uploadTask.ref.getDownloadURL();
  return downloadUrl;
}
