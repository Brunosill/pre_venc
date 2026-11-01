import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../domain/entities/product.dart';
import '../../utils/product_parser.dart';

class BarcodeLookupService {
  static const _baseUrl = 'https://world.openfoodfacts.org/api/v2/product';
  static const _timeout = Duration(seconds: 5);

  Future<ProductSuggestion?> lookup(String barcode) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/$barcode.json'),
            headers: {'User-Agent': 'PreVenc/1.0 (Flutter App)'},
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 1) return null;

      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final name = (product['product_name'] as String?)?.trim();
      final genericName = (product['generic_name'] as String?)?.trim();

      return ProductSuggestion(
        name: (name != null && name.isNotEmpty) ? name : genericName,
        barcode: barcode,
        source: ProductSource.barcode,
      );
    } catch (_) {
      // Timeout, sem internet, JSON inválido → retorna null
      return null;
    }
  }
}