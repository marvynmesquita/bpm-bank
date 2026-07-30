import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // Try to read .env
  dotenv.testLoad(fileInput: File('.env').readAsStringSync());
  final apiKey = dotenv.env['GEMINI_API_KEY'];
  if (apiKey == null) {
    print('No API key');
    return;
  }
  
  // We have to use a dummy model name to instantiate the client to list models? No, GenerativeModel doesn't have listModels directly in the instance, wait... no, the new SDK might have it on a client? Actually wait, let's use a dummy name.
  // Wait, the SDK `listModels` isn't a method on `GenerativeModel`. Or maybe it's not exposed in older versions. I'll just make a raw HTTP request.
  
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=\$apiKey');
  final request = await HttpClient().getUrl(url);
  final response = await request.close();
  final body = await response.transform(const SystemEncoding().decoder).join();
  print(body);
}
