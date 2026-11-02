import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteCatalogService {
  final SupabaseClient _client;
  RemoteCatalogService(this._client);

  /// Busca em products_catalog e, se não achar, em barcode_cache.
  Future<Map<String, dynamic>?> lookup(String barcode) async {
    try {
      // 1. Catálogo colaborativo (curado ou contribuído por usuários)
      final catalog = await _client
          .from('products_catalog')
          .select('name, brand, barcode, source, is_verified')
          .eq('barcode', barcode)
          .maybeSingle();

      if (catalog != null) {
        final name = catalog['name'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          return {
            'name': name.trim(),
            'brand': catalog['brand'],
            'barcode': catalog['barcode'],
            'source': 'supabase_catalog',
            'is_verified': catalog['is_verified'] ?? false,
            'raw': catalog,
          };
        }
      }

      // 2. Cache colaborativo (dados brutos de APIs externas já consultados)
      final cache = await _client
          .from('barcode_cache')
          .select('payload, source')
          .eq('barcode', barcode)
          .maybeSingle();

      if (cache != null && cache['payload'] != null) {
        final payload = cache['payload'] as Map<String, dynamic>;
        return {
          ...payload,
          'source': 'supabase_cache',
        };
      }

      return null;
    } catch (e) {
      debugPrint('RemoteCatalogService.lookup erro: $e');
      return null;
    }
  }

  /// Publica uma resposta bem-sucedida no cache colaborativo.
  /// Fire-and-forget — erros são silenciosos.
  Future<void> publishToCache(String barcode, Map<String, dynamic> data) async {
    try {
      await _client.from('barcode_cache').upsert({
        'barcode': barcode,
        'source': data['source'] ?? 'unknown',
        'payload': data,
        'fetched_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('RemoteCatalogService.publishToCache erro: $e');
    }
  }
}