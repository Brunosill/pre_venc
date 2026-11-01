import 'package:hive/hive.dart';

@HiveType(typeId: 20)
class ProductModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? barcode;

  @HiveField(3)
  final DateTime? manufacturingDate;

  @HiveField(4)
  final DateTime? expirationDate;

  @HiveField(5)
  final String? imagePath;

  @HiveField(6)
  final String? ocrText;

  @HiveField(7)
  final DateTime createdAt;

  ProductModel({
    required this.id,
    required this.name,
    this.barcode,
    this.manufacturingDate,
    this.expirationDate,
    this.imagePath,
    this.ocrText,
    required this.createdAt,
  });
}

class ProductModelAdapter extends TypeAdapter<ProductModel> {
  @override
  final int typeId = 20;

  @override
  ProductModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductModel(
      id: fields[0] as String,
      name: fields[1] as String,
      barcode: fields[2] as String?,
      manufacturingDate: fields[3] as DateTime?,
      expirationDate: fields[4] as DateTime?,
      imagePath: fields[5] as String?,
      ocrText: fields[6] as String?,
      createdAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ProductModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.name)
      ..writeByte(2)..write(obj.barcode)
      ..writeByte(3)..write(obj.manufacturingDate)
      ..writeByte(4)..write(obj.expirationDate)
      ..writeByte(5)..write(obj.imagePath)
      ..writeByte(6)..write(obj.ocrText)
      ..writeByte(7)..write(obj.createdAt);
  }
}