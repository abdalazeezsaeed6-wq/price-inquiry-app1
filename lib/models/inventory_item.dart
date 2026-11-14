class InventoryItem {
  final int? id;
  final String name;
  final String itemCode;
  final String barcode;
  final double purchasePrice;
  final double sellingPrice;
  final String unit;
  final double quantity;
  final String notes;
  final String createdAt;

  InventoryItem({
    this.id,
    required this.name,
    required this.itemCode,
    this.barcode = '',
    required this.purchasePrice,
    required this.sellingPrice,
    this.unit = 'حبة',
    this.quantity = 0,
    this.notes = '',
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name.trim(),
        'item_code': itemCode.trim(),
        'barcode': barcode.trim().isEmpty ? null : barcode.trim(),
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        'unit': unit.trim().isEmpty ? 'حبة' : unit.trim(),
        'quantity': quantity,
        'notes': notes,
        'created_at': createdAt,
      };

  factory InventoryItem.fromMap(Map<String, Object?> map) {
    return InventoryItem(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      itemCode: map['item_code'] as String? ?? '',
      barcode: map['barcode'] as String? ?? '',
      purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0,
      sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0,
      unit: map['unit'] as String? ?? 'حبة',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String? ?? '',
      createdAt: map['created_at'] as String?,
    );
  }
}
