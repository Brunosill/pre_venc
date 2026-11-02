import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> extractText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(inputImage);

    final buffer = StringBuffer();
    for (final block in recognized.blocks) {
      buffer.writeln(block.text);
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  void dispose() {
    _recognizer.close();
  }
}