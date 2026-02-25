import 'package:isar/isar.dart';

part 'product_isar.g.dart';

/// Modelo Isar para Produto com suporte completo a Delta Sync
/// 
/// Este modelo inclui:
/// - Timestamps para sincronização (createdAt, updatedAt, lastSyncedAt)
/// - Flags de controle (isSynced, isDeleted)
/// - Índices otimizados para queries de sincronização
@collection
class ProductIsar {
  Id id = Isar.autoIncrement; // ID local auto-incrementado
  
  /// ID único do servidor (UUID)
  @Index(unique: true)
  late String serverId;
  
  /// ID do usuário proprietário
  @Index()
  late String userId;
  
  // Dados do produto
  late String name;
  late double price;
  late String description;
  String? imagePath;
  late String region;
  late String wineType;
  late int quantity;
  String? location; // Localização da adega
  
  /// Timestamp de criação no servidor (ISO 8601)
  @Index()
  late DateTime createdAt;
  
  /// Timestamp da última modificação no servidor (ISO 8601)
  /// CRÍTICO: Usado para Delta Sync - sempre atualizado pelo servidor
  @Index()
  late DateTime updatedAt;
  
  /// Timestamp da última sincronização com sucesso
  /// Usado para saber até quando este dispositivo está sincronizado
  DateTime? lastSyncedAt;
  
  /// Flag indicando se há mudanças locais pendentes de upload
  @Index()
  late bool hasPendingChanges;
  
  /// Flag soft-delete (não apaga do banco, marca como deletado)
  @Index()
  late bool isDeleted;
  
  /// Número de versão para resolver conflitos (incrementado a cada mudança)
  late int version;
  
  /// Construtor
  ProductIsar({
    this.id = Isar.autoIncrement,
    required this.serverId,
    required this.userId,
    required this.name,
    required this.price,
    required this.description,
    this.imagePath,
    required this.region,
    required this.wineType,
    this.quantity = 0,
    this.location,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastSyncedAt,
    this.hasPendingChanges = false,
    this.isDeleted = false,
    this.version = 1,
  }) {
    final now = DateTime.now().toUtc();
    this.createdAt = createdAt ?? now;
    this.updatedAt = updatedAt ?? now;
  }
  
  /// Factory para criar a partir de JSON da API
  factory ProductIsar.fromJson(Map<String, dynamic> json) {
    return ProductIsar(
      serverId: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      description: json['description'] as String,
      imagePath: json['imagePath'] as String?,
      region: json['region'] as String,
      wineType: json['wineType'] as String,
      quantity: json['quantity'] as int? ?? 0,
      location: json['location'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      version: json['version'] as int? ?? 1,
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }
  
  /// Converte para JSON para enviar à API
  Map<String, dynamic> toJson() {
    return {
      'id': serverId,
      'userId': userId,
      'name': name,
      'price': price,
      'description': description,
      'imagePath': imagePath,
      'region': region,
      'wineType': wineType,
      'quantity': quantity,
      'location': location,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'version': version,
      'isDeleted': isDeleted,
    };
  }
  
  /// Atualiza os dados mantendo metadata
  void updateFrom(ProductIsar other) {
    name = other.name;
    price = other.price;
    description = other.description;
    imagePath = other.imagePath;
    region = other.region;
    wineType = other.wineType;
    quantity = other.quantity;
    location = other.location;
    updatedAt = other.updatedAt;
    version = other.version;
    isDeleted = other.isDeleted;
  }
}

/// Metadata de sincronização global
@collection
class SyncMetadata {
  Id id = Isar.autoIncrement;
  
  /// Chave única (ex: "products_last_sync", "initial_sync_completed")
  @Index(unique: true)
  late String key;
  
  /// Valor (pode ser timestamp, boolean como string, etc)
  late String value;
  
  /// Última atualização deste metadata
  late DateTime updatedAt;
  
  SyncMetadata({
    this.id = Isar.autoIncrement,
    required this.key,
    required this.value,
    DateTime? updatedAt,
  }) {
    this.updatedAt = updatedAt ?? DateTime.now().toUtc();
  }
}
