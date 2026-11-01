import 'package:hive/hive.dart';

@HiveType(typeId: 40)
class BarcodeCacheModel extends HiveObject {
  @HiveField(0) final String barcode;
  @HiveField(1) final String? name;
  @HiveField(2) final String? brand;
  @HiveField(3) final String? category;
  @HiveField(4) final String? source;
  @HiveField(5) final DateTime fetchedAt;
  @HiveField(6) final Map<String, dynamic>? rawPayload;

  BarcodeCacheModel({
    required this.barcode,
    this.name,
    this.brand,
    this.category,
    this.source,
    required this.fetchedAt,
    this.rawPayload,
  });

  bool get isExpired =>
      DateTime.now().difference(fetchedAt).inDays > 30;
}

class BarcodeCacheModelAdapter extends TypeAdapter<BarcodeCacheModel> {
  @override final int typeId = 40;

  @override
  BarcodeCacheModel read(BinaryReader reader) {
    final n = reader.readByte();
    final f = <int, dynamic>{for (var i = 0; i < n; i++) reader.readByte(): reader.read()};
    return BarcodeCacheModel(
      barcode: f[0] as String,
      name: f[1] as String?,
      brand: f[2] as String?,
      category: f[3] as String?,
      source: f[4] as String?,
      fetchedAt: f[5] as DateTime,
      rawPayload: (f[6] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, BarcodeCacheModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)..write(obj.barcode)
      ..writeByte(1)..write(obj.name)
      ..writeByte(2)..write(obj.brand)
      ..writeByte(3)..write(obj.category)
      ..writeByte(4)..write(obj.source)
      ..writeByte(5)..write(obj.fetchedAt)
      ..writeByte(6)..write(obj.rawPayload);
  }
}