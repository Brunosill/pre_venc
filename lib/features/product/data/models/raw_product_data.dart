import 'package:hive/hive.dart';

@HiveType(typeId: 50)
class RawProductData extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? barcode;

  @HiveField(2)
  final String? imagePath1;

  @HiveField(3)
  final String? imagePath2;

  @HiveField(4)
  final String? ocrText1;

  @HiveField(5)
  final String? ocrText2;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final int ocrStatus; // 0=Pendente, 1=Sucesso, 2=Falha

  RawProductData({
    required this.id,
    this.barcode,
    this.imagePath1,
    this.imagePath2,
    this.ocrText1,
    this.ocrText2,
    required this.createdAt,
    this.ocrStatus = 0,
  });
}

class RawProductDataAdapter extends TypeAdapter<RawProductData> {
  @override
  final int typeId = 50;

  @override
  RawProductData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RawProductData(
      id: fields[0] as String,
      barcode: fields[1] as String?,
      imagePath1: fields[2] as String?,
      imagePath2: fields[3] as String?,
      ocrText1: fields[4] as String?,
      ocrText2: fields[5] as String?,
      createdAt: fields[6] as DateTime,
      ocrStatus: fields[7] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, RawProductData obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.barcode)
      ..writeByte(2)..write(obj.imagePath1)
      ..writeByte(3)..write(obj.imagePath2)
      ..writeByte(4)..write(obj.ocrText1)
      ..writeByte(5)..write(obj.ocrText2)
      ..writeByte(6)..write(obj.createdAt)
      ..writeByte(7)..write(obj.ocrStatus);
  }
}