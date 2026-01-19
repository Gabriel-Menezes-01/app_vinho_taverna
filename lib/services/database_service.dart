import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/user.dart';
import '../models/wine.dart';
import '../models/sale.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'app_vinho_taverna.db';

  /// Inicializa sqflite FFI para Windows/Linux
  static Future<void> initializeFFI() async {
    if (Platform.isWindows || Platform.isLinux) {
      try {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        debugPrint('✓ SQLite FFI inicializado com sucesso');
      } catch (e) {
        debugPrint('⚠️ Erro ao inicializar FFI: $e');
        rethrow;
      }
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: 5, // Incrementado para adicionar coluna location
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Recriar a tabela wines para adicionar/corrigir coluna quantity
      // SQLite não suporta ALTER COLUMN, então precisamos recriar a tabela
      await db.execute('''
        CREATE TABLE wines_new (
          id TEXT PRIMARY KEY,
          user_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          price REAL NOT NULL,
          description TEXT NOT NULL,
          image_path TEXT,
          region TEXT NOT NULL,
          wine_type TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 0,
          synced INTEGER NOT NULL DEFAULT 0,
          last_modified TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');

      // Verificar se a coluna quantity já existe na tabela antiga
      final columns = await db.rawQuery('PRAGMA table_info(wines)');
      final hasQuantity = columns.any((col) => col['name'] == 'quantity');

      if (hasQuantity) {
        // Copiar dados incluindo quantity
        await db.execute('''
          INSERT INTO wines_new (id, user_id, name, price, description, image_path, region, wine_type, quantity, synced, last_modified, created_at)
          SELECT id, user_id, name, price, description, image_path, region, wine_type, quantity, synced, last_modified, created_at
          FROM wines
        ''');
      } else {
        // Copiar dados sem quantity (definir padrão 0)
        await db.execute('''
          INSERT INTO wines_new (id, user_id, name, price, description, image_path, region, wine_type, quantity, synced, last_modified, created_at)
          SELECT id, user_id, name, price, description, image_path, region, wine_type, 0, synced, last_modified, created_at
          FROM wines
        ''');
      }

      // Remover tabela antiga
      await db.execute('DROP TABLE wines');

      // Renomear nova tabela
      await db.execute('ALTER TABLE wines_new RENAME TO wines');

      // Recriar índice
      await db.execute('CREATE INDEX idx_wines_user_id ON wines(user_id)');
    }
    
    if (oldVersion < 4) {
      // Adicionar tabela de vendas
      await db.execute('''
        CREATE TABLE sales (
          id TEXT PRIMARY KEY,
          wine_id TEXT NOT NULL,
          wine_name TEXT NOT NULL,
          wine_price REAL NOT NULL,
          quantity INTEGER NOT NULL,
          sale_date TEXT NOT NULL,
          user_id INTEGER NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');
      
      await db.execute('CREATE INDEX idx_sales_user_id ON sales(user_id)');
      await db.execute('CREATE INDEX idx_sales_date ON sales(sale_date)');
    }
    
    if (oldVersion < 5) {
      // Adicionar coluna location à tabela wines
      await db.execute('ALTER TABLE wines ADD COLUMN location TEXT');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabela de usuários
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Tabela de vinhos
    await db.execute('''
      CREATE TABLE wines (
        id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        description TEXT NOT NULL,
        image_path TEXT,
        region TEXT NOT NULL,
        wine_type TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0,
        location TEXT,
        synced INTEGER NOT NULL DEFAULT 0,
        last_modified TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Índice para melhorar performance
    await db.execute('CREATE INDEX idx_wines_user_id ON wines(user_id)');
    
    // Tabela de vendas
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        wine_id TEXT NOT NULL,
        wine_name TEXT NOT NULL,
        wine_price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        sale_date TEXT NOT NULL,
        user_id INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
    
    await db.execute('CREATE INDEX idx_sales_user_id ON sales(user_id)');
    await db.execute('CREATE INDEX idx_sales_date ON sales(sale_date)');
  }

  // ========== USUÁRIOS ==========

  Future<int> createUser(String username, String password) async {
    final db = await database;
    return await db.insert('users', {
      'username': username,
      'password': password,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<User?> getUserByUsername(String username) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (maps.isEmpty) return null;

    return User.fromMap(maps.first);
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    return User.fromMap(maps.first);
  }

  // ========== VINHOS ==========

  Future<int> insertWine(Wine wine, int userId) async {
    final db = await database;
    final data = wine.toMap();
    data['user_id'] = userId;
    data['created_at'] = DateTime.now().toIso8601String();
    return await db.insert('wines', data);
  }

  Future<int> updateWine(Wine wine, int userId) async {
    final db = await database;
    final data = wine.toMap();
    data['user_id'] = userId;
    return await db.update(
      'wines',
      data,
      where: 'id = ? AND user_id = ?',
      whereArgs: [wine.id, userId],
    );
  }

  Future<int> deleteWine(String wineId, int userId) async {
    final db = await database;
    return await db.delete(
      'wines',
      where: 'id = ? AND user_id = ?',
      whereArgs: [wineId, userId],
    );
  }

  Future<List<Wine>> getWinesByUser(int userId) async {
    final db = await database;
    final maps = await db.query(
      'wines',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => Wine.fromMap(map)).toList();
  }

  Future<Wine?> getWineById(String wineId, int userId) async {
    final db = await database;
    final maps = await db.query(
      'wines',
      where: 'id = ? AND user_id = ?',
      whereArgs: [wineId, userId],
    );

    if (maps.isEmpty) return null;

    return Wine.fromMap(maps.first);
  }

  // ========== SINCRONIZAÇÃO ==========

  Future<List<Wine>> getUnsyncedWines(int userId) async {
    final db = await database;
    final maps = await db.query(
      'wines',
      where: 'user_id = ? AND synced = 0',
      whereArgs: [userId],
    );

    return maps.map((map) => Wine.fromMap(map)).toList();
  }

  Future<void> markWineAsSynced(String wineId, int userId) async {
    final db = await database;
    await db.update(
      'wines',
      {'synced': 1},
      where: 'id = ? AND user_id = ?',
      whereArgs: [wineId, userId],
    );
  }

  Future<void> markAllWinesAsSynced(int userId) async {
    final db = await database;
    await db.update(
      'wines',
      {'synced': 1},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // ========== VENDAS ==========

  Future<int> insertSale(Sale sale) async {
    final db = await database;
    return await db.insert('sales', sale.toMap());
  }

  Future<List<Sale>> getSalesByUserAndMonth(int userId, DateTime month) async {
    final db = await database;
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    
    final maps = await db.query(
      'sales',
      where: 'user_id = ? AND sale_date >= ? AND sale_date <= ?',
      whereArgs: [userId, firstDay.toIso8601String(), lastDay.toIso8601String()],
      orderBy: 'sale_date DESC',
    );

    return maps.map((map) => Sale.fromMap(map)).toList();
  }

  Future<List<Sale>> getSalesByUserAndDay(int userId, DateTime day) async {
    final db = await database;
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);
    
    final maps = await db.query(
      'sales',
      where: 'user_id = ? AND sale_date >= ? AND sale_date <= ?',
      whereArgs: [userId, startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'sale_date DESC',
    );

    return maps.map((map) => Sale.fromMap(map)).toList();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
