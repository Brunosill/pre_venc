import 'package:uuid/uuid.dart';

class InventoryId {
  /// Gera um ID estável baseado em barcode + lote.
  /// Se ambos existirem, retorna "${barcode}_${lote}" em maiúsculas.
  /// Se faltar algum, retorna UUID (cada entrada é única).
  static String generate({String? barcode, String? lote}) {
    final bc = barcode?.trim();
    final lt = lote?.trim().toUpperCase();

    if (bc != null && bc.isNotEmpty && lt != null && lt.isNotEmpty) {
      return '${bc}_$lt';
    }
    return const Uuid().v4();
  }

  /// True se o ID segue o padrão determinístico (barcode_lote).
  static bool isDeterministic(String id) {
    return id.contains('_') && !id.startsWith('manual_');
  }
}