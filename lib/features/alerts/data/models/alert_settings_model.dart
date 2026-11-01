import 'package:hive/hive.dart';

@HiveType(typeId: 30)
class AlertSettingsModel extends HiveObject {
  @HiveField(0)
  final List<int> daysBefore;

  @HiveField(1)
  final bool enabled;

  AlertSettingsModel({
    required this.daysBefore,
    required this.enabled,
  });
}

class AlertSettingsModelAdapter extends TypeAdapter<AlertSettingsModel> {
  @override
  final int typeId = 30;

  @override
  AlertSettingsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AlertSettingsModel(
      daysBefore: (fields[0] as List?)?.cast<int>() ?? const [30, 1],
      enabled: fields[1] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, AlertSettingsModel obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)..write(obj.daysBefore)
      ..writeByte(1)..write(obj.enabled);
  }
}