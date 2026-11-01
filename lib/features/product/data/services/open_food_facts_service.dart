import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/product_category.dart';

class OpenFoodFactsService {
  static const _base = 'https://world.openfoodfacts.org/api/v2/product';
  static const _timeout = Duration(seconds: 8);

  final http.Client _client;

  OpenFoodFactsService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>?> lookup(String barcode) async {
    try {
      final url = Uri.parse(
        '$_base/$barcode.json?fields=product_name,brands,ingredients_text,'
        'allergens,nutriscore_grade,nova_group,image_front_url',
      );
      final r = await _client
          .get(url, headers: {'User-Agent': 'PreVenc/1.0'})
          .timeout(_timeout);
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (data['status'] != 1) return null;
      final p = data['product'] as Map<String, dynamic>?;
      if (p == null) return null;
      return {
        'name': p['product_name'],
        'brand': p['brands'],
        'category': ProductCategory.food.name,
        'source': 'openfoodfacts',
        'raw': p,
      };
    } catch (_) {
      return null;
    }
  }
}
