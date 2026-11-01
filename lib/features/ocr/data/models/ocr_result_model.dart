import 'package:hive/hive.dart';

@HiveType(typeId: 10)
class OcrResultModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String imagePath;

  @HiveField(2)
  final String extractedText;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final int textLength;

  OcrResultModel({
    required this.id,
    required this.imagePath,
    required this.extractedText,
    required this.createdAt,
    required this.textLength,
  });
}

class OcrResultModelAdapter extends TypeAdapter<OcrResultModel> {
  @override
  final int typeId = 10;

  @override
  OcrResultModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OcrResultModel(
      id: fields[0] as String,
      imagePath: fields[1] as String,
      extractedText: fields[2] as String,
      createdAt: fields[3] as DateTime,
      textLength: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, OcrResultModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.imagePath)
      ..writeByte(2)..write(obj.extractedText)
      ..writeByte(3)..write(obj.createdAt)
      ..writeByte(4)..write(obj.textLength);
  }
}