import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/product.dart';

class CatalogContributionService {
  final SupabaseClient _client;

  CatalogContributionService(this._client);

  /// Verifica se o código já está no catálogo público.
  Future<bool> isInCatalog(String barcode) async {
    try {
      final response = await _client
          .from('products_catalog')
          .select('id')
          .eq('barcode', barcode)
          .maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('Erro ao verificar catálogo: $e');
      return false;
    }
  }

  /// Contribui com um produto ao catálogo público.
  /// Sempre com `is_verified = false`.
  Future<bool> contribute(Product product) async {
    if (product.barcode == null || product.barcode!.isEmpty) {
      return false;
    }

    if (await isInCatalog(product.barcode!)) {
      debugPrint('Produto já está no catálogo: ${product.barcode}');
      return false;
    }

    try {
      final user = _client.auth.currentUser;

      await _client.from('products_catalog').insert({
        'barcode': product.barcode,
        'name': product.name,
        'source': 'user_contribution',
        'is_verified': false,
        'created_by': user?.id,
      });

      debugPrint('Produto contribuído: ${product.name}');
      return true;
    } catch (e) {
      debugPrint('Erro ao contribuir: $e');
      return false;
    }
  }
}