class User {
  int? id;
  String username;
  String email;
  String password;
  DateTime? createdAt;
  String? firebaseUid;

  User({
    this.id,
    required this.username,
    required this.email,
    required this.password,
    this.createdAt,
    this.firebaseUid,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password': password,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'firebase_uid': firebaseUid,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      username: map['username'] as String,
      email: map['email'] as String,
      password: map['password'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      firebaseUid: map['firebase_uid'] as String?,
    );
  }

  // Métodos para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'email': email,
      'createdAt':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'firebaseUid': firebaseUid,
      // Senha não é salva no Firestore (está no Firebase Auth)
    };
  }

  factory User.fromFirestore(Map<String, dynamic> map, String firebaseUid) {
    return User(
      id: firebaseUid.hashCode.abs(), // Converter UID do Firebase em int
      username: map['username'] as String,
      email: map['email'] as String? ?? '',
      password: '', // Senha não é armazenada no Firestore
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      firebaseUid: firebaseUid,
    );
  }
}
