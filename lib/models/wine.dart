class Wine {
  String id;
  String name;
  double price;
  String description;
  String? imagePath;
  String? imageUrl;
  String region;
  String wineType; // tinto, branco, rosé, verde, espumante, champagne
  int quantity; // Quantidade de garrafas disponíveis
  String? location; // Local onde o vinho está armazenado
  int? harvestYear; // Ano de colheita
  bool synced; // Status de sincronização com servidor
  bool isFromAdega; // Se o vinho foi adicionado pela adega pessoal
  bool isHouseWine; // Se é vinho da casa
  bool isDailySpecial; // Se é sugestão do dia
  DateTime? lastModified; // Última modificação
  DateTime? createdAt; // Data de criação

  Wine({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    this.imagePath,
    this.imageUrl,
    this.region = 'Outra região',
    this.wineType = 'tinto',
      this.quantity = 0,
    this.location,
    this.harvestYear,
    this.synced = false,
    this.isFromAdega = false,
    this.isHouseWine = false,
    this.isDailySpecial = false,
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
      'image_url': imageUrl,
      'region': region,
      'wine_type': wineType,
        'quantity': quantity,
      'location': location,
      'harvest_year': harvestYear,
      'synced': synced ? 1 : 0,
      'is_from_adega': isFromAdega ? 1 : 0,
      'is_house_wine': isHouseWine ? 1 : 0,
      'is_daily_special': isDailySpecial ? 1 : 0,
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
      imageUrl: map['image_url'] as String?,
      region: map['region'] as String? ?? 'Outra região',
      wineType: map['wine_type'] as String? ?? 'tinto',
        quantity: (map['quantity'] as int?) ?? 0,
      location: map['location'] as String?,
      harvestYear: (map['harvest_year'] as int?),
      synced: (map['synced'] as int?) == 1,
      isFromAdega: (map['is_from_adega'] as int?) == 1,
      isHouseWine: (map['is_house_wine'] as int?) == 1,
      isDailySpecial: (map['is_daily_special'] as int?) == 1,
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
      'imageUrl': imageUrl,
      'location': location,
      'region': region,
      'wineType': wineType,
        'quantity': quantity,
      'harvestYear': harvestYear,
      'isFromAdega': isFromAdega,
      'isHouseWine': isHouseWine,
      'isDailySpecial': isDailySpecial,
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
      imageUrl: data['imageUrl'] as String? ?? data['image_url'] as String?,
      location: data['location'] as String?,
      region: data['region'] as String? ?? 'Outra região',
      wineType: data['wineType'] as String? ?? 'tinto',
        quantity: (data['quantity'] as int?) ?? 0,
      harvestYear: (data['harvestYear'] as num?)?.toInt(),
      synced: true,
      isFromAdega: data['isFromAdega'] as bool? ?? false,
      isHouseWine: data['isHouseWine'] as bool? ?? false,
      isDailySpecial: data['isDailySpecial'] as bool? ?? false,
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
    'imageUrl': imageUrl,
    'location': location,
    'wineType': wineType,
    'region': region,
    'harvestYear': harvestYear,
    'isFromAdega': isFromAdega,
    'isHouseWine': isHouseWine,
    'isDailySpecial': isDailySpecial,
  };

  factory Wine.fromJson(Map<String, dynamic> json) => Wine(
    id: json['id'],
    name: json['name'],
    price: json['price'],
    description: json['description'],
    imagePath: json['imagePath'],
    imageUrl: json['imageUrl'],
    location: json['location'],
    wineType: json['wineType'] ?? 'tinto',
    region: json['region'] ?? 'Outra região',
    quantity: (json['quantity'] as int?) ?? 0,
    harvestYear: (json['harvestYear'] as num?)?.toInt(),
    isFromAdega: json['isFromAdega'] as bool? ?? false,
    isHouseWine: json['isHouseWine'] as bool? ?? false,
    isDailySpecial: json['isDailySpecial'] as bool? ?? false,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
  );
}
