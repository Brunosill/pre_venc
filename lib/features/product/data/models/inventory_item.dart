import 'package:hive/hive.dart';

@HiveType(typeId: 51)
class InventoryItem extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) String? userId;
  @HiveField(2) final String? barcode;
  @HiveField(3) final int type;
  @HiveField(4) String name;
  @HiveField(5) String? lote;
  @HiveField(6) DateTime? manufacturingDate;
  @HiveField(7) DateTime? expirationDate;
  @HiveField(8) double quantity;
  @HiveField(9) String? unit;
  @HiveField(10) String? notes;
  @HiveField(11) final int source;
  @HiveField(12) final DateTime createdAt;
  @HiveField(13) DateTime updatedAt;
  @HiveField(14) DateTime? deletedAt;
  @HiveField(15) bool isDraft;

  // NOVOS (Sprint 7E)
  @HiveField(16) String? remoteId;        // ID no Supabase
  @HiveField(17) int syncStatus;          // 0=pending, 1=synced, 2=error, 3=deleted

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
    this.remoteId,
    this.syncStatus = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'barcode': barcode,
        'type': type,
        'name': name,
        'lote': lote,
        'manufacturingDate': manufacturingDate?.toIso8601String(),
        'expirationDate': expirationDate?.toIso8601String(),
        'quantity': quantity,
        'unit': unit,
        'notes': notes,
        'source': source,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
        'isDraft': isDraft,
        'remoteId': remoteId,
        'syncStatus': syncStatus,
      };

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'] as String,
        userId: json['userId'] as String?,
        barcode: json['barcode'] as String?,
        type: json['type'] as int? ?? 0,
        name: json['name'] as String,
        lote: json['lote'] as String?,
        manufacturingDate: json['manufacturingDate'] != null
            ? DateTime.parse(json['manufacturingDate'])
            : null,
        expirationDate: json['expirationDate'] != null
            ? DateTime.parse(json['expirationDate'])
            : null,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
        unit: json['unit'] as String? ?? 'un',
        notes: json['notes'] as String?,
        source: json['source'] as int? ?? 2,
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        deletedAt: json['deletedAt'] != null
            ? DateTime.parse(json['deletedAt'])
            : null,
        isDraft: json['isDraft'] as bool? ?? false,
        remoteId: json['remoteId'] as String?,
        syncStatus: json['syncStatus'] as int? ?? 0,
      );
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
      remoteId: fields[16] as String?,
      syncStatus: fields[17] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, InventoryItem obj) {
    writer
      ..writeByte(18)
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
      ..writeByte(15)..write(obj.isDraft)
      ..writeByte(16)..write(obj.remoteId)
      ..writeByte(17)..write(obj.syncStatus);
  }
}