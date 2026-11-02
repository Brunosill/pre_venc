import 'package:hive/hive.dart';

@HiveType(typeId: 51)
class InventoryItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? userId; // Nulo se anônimo

  @HiveField(2)
  final String? barcode;

  @HiveField(3)
  final int type; // 0=Alimento, 1=Medicamento, 2=Beleza

  @HiveField(4)
  String name;

  @HiveField(5)
  String? lote;

  @HiveField(6)
  DateTime? manufacturingDate;

  @HiveField(7)
  DateTime? expirationDate;

  @HiveField(8)
  double quantity;

  @HiveField(9)
  String? unit; // 'un', 'kg', 'L', 'mg', 'ml'

  @HiveField(10)
  String? notes;

  @HiveField(11)
  final int source; // 0=OCR, 1=Barcode, 2=Manual

  @HiveField(12)
  final DateTime createdAt;

  @HiveField(13)
  DateTime updatedAt;

  @HiveField(14)
  DateTime? deletedAt;

  // MELHORIA DE UX: Modo Mercado (Batch Scan)
  // Se true, o item foi escaneado no mercado e está aguardando ser completado.
  @HiveField(15)
  bool isDraft;

  InventoryItem({
    required this.id,
    this.userId,
    this.barcode,
    this.type = 0,
    required this.name,
    this.lote,
    this.manufacturingDate,
    this.expirationDate,
    this.quantity = 1.0,
    this.unit = 'un',
    this.notes,
    this.source = 2,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.isDraft = false,
  });
}

class InventoryItemAdapter extends TypeAdapter<InventoryItem> {
  @override
  final int typeId = 51;

  @override
  InventoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InventoryItem(
      id: fields[0] as String,
      userId: fields[1] as String?,
      barcode: fields[2] as String?,
      type: fields[3] as int? ?? 0,
      name: fields[4] as String,
      lote: fields[5] as String?,
      manufacturingDate: fields[6] as DateTime?,
      expirationDate: fields[7] as DateTime?,
      quantity: (fields[8] as num?)?.toDouble() ?? 1.0,
      unit: fields[9] as String? ?? 'un',
      notes: fields[10] as String?,
      source: fields[11] as int? ?? 2,
      createdAt: fields[12] as DateTime,
      updatedAt: fields[13] as DateTime,
      deletedAt: fields[14] as DateTime?,
      isDraft: fields[15] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, InventoryItem obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.userId)
      ..writeByte(2)..write(obj.barcode)
      ..writeByte(3)..write(obj.type)
      ..writeByte(4)..write(obj.name)
      ..writeByte(5)..write(obj.lote)
      ..writeByte(6)..write(obj.manufacturingDate)
      ..writeByte(7)..write(obj.expirationDate)
      ..writeByte(8)..write(obj.quantity)
      ..writeByte(9)..write(obj.unit)
      ..writeByte(10)..write(obj.notes)
      ..writeByte(11)..write(obj.source)
      ..writeByte(12)..write(obj.createdAt)
      ..writeByte(13)..write(obj.updatedAt)
      ..writeByte(14)..write(obj.deletedAt)
      ..writeByte(15)..write(obj.isDraft);
  }
}