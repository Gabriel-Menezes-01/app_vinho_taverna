class Sale {
  String id;
  String wineId;
  String wineName;
  double winePrice;
  int quantity;
  DateTime saleDate;
  int userId;

  Sale({
    required this.id,
    required this.wineId,
    required this.wineName,
    required this.winePrice,
    required this.quantity,
    required this.saleDate,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wine_id': wineId,
      'wine_name': wineName,
      'wine_price': winePrice,
      'quantity': quantity,
      'sale_date': saleDate.toIso8601String(),
      'user_id': userId,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as String,
      wineId: map['wine_id'] as String,
      wineName: map['wine_name'] as String,
      winePrice: (map['wine_price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      saleDate: DateTime.parse(map['sale_date'] as String),
      userId: map['user_id'] as int,
    );
  }

  double get totalValue => winePrice * quantity;
}
