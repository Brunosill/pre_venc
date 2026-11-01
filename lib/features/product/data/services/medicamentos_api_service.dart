import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/product_category.dart';

class MedicamentosApiService {
  static const _base = 'https://medicamentos.api.br/api/v1';
  static const _timeout = Duration(seconds: 8);

  final String? _apiKey;
  final http.Client _client;

  // ignore: prefer_initializing_formals
  MedicamentosApiService({String? apiKey, http.Client? client})
      : _apiKey = apiKey,
        _client = client ?? http.Client();

  bool get isConfigured => _apiKey != null && _apiKey.isNotEmpty;

  Future<Map<String, dynamic>?> lookup(String barcode) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) return null;

    try {
      final url = Uri.parse('$_base/ean/$barcode');
      final r = await _client.get(url, headers: {
        'X-API-Key': key,
        'User-Agent': 'PreVenc/1.0',
      }).timeout(_timeout);

      if (r.statusCode == 429) return null;
      if (r.statusCode != 200) return null;

      final data = jsonDecode(r.body) as Map<String, dynamic>;
      return {
        'name': data['nomeComercial'] ?? data['nome'] ?? data['name'],
        'brand': data['laboratorio'] ?? data['marca'],
        'category': ProductCategory.medicine.name,
        'source': 'medicamentos_api',
        'raw': data,
      };
    } catch (_) {
      return null;
    }
  }
}