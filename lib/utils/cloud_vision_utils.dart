import 'dart:convert';
// REMOVE: import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;

class CloudVisionUtils {
  static const String _apiKey = 'AIzaSyCWMhM9LLHn6vJfbkM02qeMjO2oz6OUdGM';

  static Future<List<Map<String, dynamic>>> detectObjects(
    dynamic imageFile,
  ) async {
    List<int> bytes;

    try {
      if (kIsWeb) {
        if (imageFile is html.File) {
          final reader = html.FileReader();
          reader.readAsArrayBuffer(imageFile);
          await reader.onLoad.first;
          bytes = reader.result as List<int>;
        } else if (imageFile is List<int>) {
          bytes = imageFile;
        } else {
          throw Exception('Unsupported web image file type');
        }
      } else {
        if (imageFile is List<int>) {
          bytes = imageFile;
        } else if (imageFile.readAsBytesSync != null) {
          bytes = imageFile.readAsBytesSync();
        } else {
          throw Exception('Unsupported image file type');
        }
      }

      final base64Image = base64Encode(bytes);

      final url =
          'https://vision.googleapis.com/v1/images:annotate?key=$_apiKey';
      final body = jsonEncode({
        "requests": [
          {
            "image": {"content": base64Image},
            "features": [
              {"type": "OBJECT_LOCALIZATION", "maxResults": 10},
            ],
          },
        ],
      });

      final response = await http.post(
        Uri.parse(url),
        body: body,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Cloud Vision API error: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final objects =
          data['responses'][0]['localizedObjectAnnotations'] as List?;
      if (objects == null) return [];

      return objects
          .map(
            (obj) => {
              'name': obj['name'],
              'score': obj['score'],
              'boundingPoly': obj['boundingPoly'],
            },
          )
          .toList();
    } catch (e) {
      print('Error in detectObjects: $e');
      rethrow;
    }
  }
}
