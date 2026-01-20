class Wine {
  String id;
  String name;
  double price;
  String description;
  String? imagePath;
  String region;
  String wineType; // tinto, branco, rosé, verde
  int quantity; // Quantidade de garrafas disponíveis
  String? location; // Local onde o vinho está armazenado
  bool synced; // Status de sincronização com servidor
  DateTime? lastModified; // Última modificação
  DateTime? createdAt; // Data de criação

  Wine({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    this.imagePath,
    this.region = 'Outra região',
    this.wineType = 'tinto',
      this.quantity = 0,
    this.location,
    this.synced = false,
    this.lastModified,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'image_path': imagePath,
      'region': region,
      'wine_type': wineType,
        'quantity': quantity,
      'location': location,
      'synced': synced ? 1 : 0,
      'last_modified': lastModified?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory Wine.fromMap(Map<String, dynamic> map) {
    return Wine(
      id: map['id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      description: map['description'] as String,
      imagePath: map['image_path'] as String?,
      region: map['region'] as String? ?? 'Outra região',
      wineType: map['wine_type'] as String? ?? 'tinto',
        quantity: (map['quantity'] as int?) ?? 0,
      location: map['location'] as String?,
      synced: (map['synced'] as int?) == 1,
      lastModified: map['last_modified'] != null
          ? DateTime.parse(map['last_modified'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  // Para Firebase Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'imagePath': imagePath,
      'region': region,
      'wineType': wineType,
        'quantity': quantity,
      'lastModified': lastModified?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory Wine.fromFirestore(Map<String, dynamic> data) {
    return Wine(
      id: data['id'] as String,
      name: data['name'] as String,
      price: (data['price'] as num).toDouble(),
      description: data['description'] as String,
      imagePath: data['imagePath'] as String?,
      region: data['region'] as String? ?? 'Outra região',
      wineType: data['wineType'] as String? ?? 'tinto',
        quantity: (data['quantity'] as int?) ?? 0,
      synced: true,
      lastModified: data['lastModified'] != null
          ? DateTime.parse(data['lastModified'] as String)
          : null,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
      'quantity': quantity,
    'id': id,
    'name': name,
    'price': price,
    'description': description,
    'imagePath': imagePath,
    'wineType': wineType,
    'region': region,
  };

  factory Wine.fromJson(Map<String, dynamic> json) => Wine(
    id: json['id'],
    name: json['name'],
    price: json['price'],
    description: json['description'],
    imagePath: json['imagePath'],
    wineType: json['wineType'] ?? 'tinto',
    region: json['region'] ?? 'Outra região',
    quantity: (json['quantity'] as int?) ?? 0,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
  );
}
