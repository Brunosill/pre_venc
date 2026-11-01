enum ProductCategory { food, medicine, beauty }

extension ProductCategoryX on ProductCategory {
  String get label {
    switch (this) {
      case ProductCategory.food: return '🍎 Alimento';
      case ProductCategory.medicine: return '💊 Medicamento';
      case ProductCategory.beauty: return '🧴 Beleza';
    }
  }

  String get apiSourceLabel {
    switch (this) {
      case ProductCategory.food: return 'Open Food Facts';
      case ProductCategory.medicine: return 'ANVISA (medicamentos.api.br)';
      case ProductCategory.beauty: return 'Open Beauty Facts';
    }
  }
}