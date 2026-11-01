class OcrResult {
  final String id;
  final String imagePath;
  final String extractedText;
  final DateTime createdAt;
  final int textLength;

  OcrResult({
    required this.id,
    required this.imagePath,
    required this.extractedText,
    required this.createdAt,
    required this.textLength,
  });

  String get previewText {
    if (extractedText.length <= 100) return extractedText;
    return '${extractedText.substring(0, 100)}...';
  }
}