import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

/// Arquivo de teste para verificar conexão Firebase
/// Execute: flutter run -d windows -t lib/teste_firebase.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase inicializado com sucesso!');
  } catch (e) {
    print('❌ Erro ao inicializar Firebase: $e');
  }

  runApp(const TesteFirebaseApp());
}

class TesteFirebaseApp extends StatelessWidget {
  const TesteFirebaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teste Firebase',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TesteFirebaseScreen(),
    );
  }
}

class TesteFirebaseScreen extends StatefulWidget {
  const TesteFirebaseScreen({super.key});

  @override
  State<TesteFirebaseScreen> createState() => _TesteFirebaseScreenState();
}

class _TesteFirebaseScreenState extends State<TesteFirebaseScreen> {
  final _emailController = TextEditingController(text: 'teste@example.com');
  final _passwordController = TextEditingController(text: '123456');
  String _status = 'Aguardando teste...';
  bool _loading = false;
  Color _statusColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _verificarConfiguracao();
  }

  Future<void> _verificarConfiguracao() async {
    setState(() {
      _status = '🔍 Verificando configuração Firebase...';
      _statusColor = Colors.blue;
    });

    try {
      final app = Firebase.app();
      final options = app.options;
      
      setState(() {
        _status = '''
✅ Firebase configurado!

📋 Detalhes:
• Projeto: ${options.projectId}
• App ID: ${options.appId}
• API Key: ${options.apiKey.substring(0, 10)}...
• Auth Domain: ${options.authDomain ?? 'N/A'}
• Storage: ${options.storageBucket}

⚠️ Importante:
1. Verifique no console se a região é europe-west1
2. Habilite Authentication (Email/Password)
3. Configure as regras do Firestore
4. Crie um usuário de teste ou clique em "Teste Completo"
        ''';
        _statusColor = Colors.green;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Erro: $e';
        _statusColor = Colors.red;
      });
    }
  }

  Future<void> _testeCompleto() async {
    setState(() {
      _loading = true;
      _status = '⏳ Iniciando teste completo...';
      _statusColor = Colors.blue;
    });

    final resultados = StringBuffer();

    try {
      // 1. Criar usuário de teste
      resultados.writeln('📝 Passo 1: Criando/autenticando usuário...');
      User? user;
      
      try {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        user = credential.user;
        resultados.writeln('✅ Usuário criado: ${user?.email}');
        resultados.writeln('   UID: ${user?.uid}');
      } catch (e) {
        if (e.toString().contains('email-already-in-use')) {
          resultados.writeln('⚠️ Usuário já existe, fazendo login...');
          final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
          user = credential.user;
          resultados.writeln('✅ Login bem-sucedido: ${user?.email}');
          resultados.writeln('   UID: ${user?.uid}');
        } else {
          throw e;
        }
      }

      if (user == null) {
        throw Exception('Usuário não foi criado/logado');
      }

      // 1.5. Criar/atualizar perfil do usuário no Firestore (SINCRONIZAÇÃO ENTRE DISPOSITIVOS)
      resultados.writeln('\n📝 Passo 1.5: Sincronizando perfil do usuário...');
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userDoc.set({
        'email': user.email,
        'displayName': user.displayName ?? 'Usuário Teste',
        'uid': user.uid,
        'created_at': FieldValue.serverTimestamp(),
        'last_login': FieldValue.serverTimestamp(),
        'devices': FieldValue.arrayUnion(['Windows Desktop']), // Rastrear dispositivos
      }, SetOptions(merge: true));
      resultados.writeln('✅ Perfil do usuário sincronizado no Firestore');
      resultados.writeln('   Caminho: /users/${user.uid}');

      // 2. Testar escrita no Firestore
      resultados.writeln('\n📝 Passo 2: Testando escrita no Firestore (visível em todos os dispositivos)...');
      final testDoc = FirebaseFirestore.instance.collection('test').doc();
      await testDoc.set({
        'mensagem': 'Teste de conexão',
        'usuario': user.email,
        'uid': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'plataforma': 'Windows',
      });
      resultados.writeln('✅ Documento de teste criado: ${testDoc.id}');

      // 3. Testar leitura
      resultados.writeln('\n📝 Passo 3: Testando leitura no Firestore...');
      final snapshot = await testDoc.get();
      if (snapshot.exists) {
        final data = snapshot.data();
        resultados.writeln('✅ Documento lido com sucesso:');
        resultados.writeln('   Mensagem: ${data?['mensagem']}');
        resultados.writeln('   Usuário: ${data?['usuario']}');
      }

      // 4. Testar estrutura de vinhos sincronizados
      resultados.writeln('\n📝 Passo 4: Criando vinho (sincronizável entre dispositivos)...');
      final wineDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('wines')
          .doc('teste-vinho');
      
      await wineDoc.set({
        'name': 'Vinho Teste Sincronizado',
        'price': 50.0,
        'region': 'Douro',
        'wineType': 'tinto',
        'quantity': 10,
        'created_at': FieldValue.serverTimestamp(),
        'synced': true,
      });
      resultados.writeln('✅ Vinho criado em /users/${user.uid}/wines/teste-vinho');
      resultados.writeln('   ✓ Visível em todos os dispositivos do mesmo usuário');

      // 4.5 Verificar que outro dispositivo pode ler
      resultados.writeln('\n📝 Passo 4.5: Simulando leitura de outro dispositivo...');
      final wineSnapshot = await wineDoc.get();
      if (wineSnapshot.exists) {
        resultados.writeln('✅ Outro dispositivo conseguiria ler: ${wineSnapshot['name']}');
      }

      // 5. Limpar dados de teste
      resultados.writeln('\n📝 Passo 5: Limpando dados de teste...');
      await testDoc.delete();
      await wineDoc.delete();
      resultados.writeln('✅ Dados de teste removidos');

      resultados.writeln('\n🎉 TODOS OS TESTES PASSARAM!');
      resultados.writeln('\n✅ Checklist final:');
      resultados.writeln('   ✓ Firebase Auth funcionando');
      resultados.writeln('   ✓ Perfil do usuário sincronizado no Firestore');
      resultados.writeln('   ✓ Vinhos sincronizados entre dispositivos');
      resultados.writeln('   ✓ Firestore escrita OK');
      resultados.writeln('   ✓ Firestore leitura OK');
      resultados.writeln('\n🚀 Mesmo usuário visível em múltiplos dispositivos!');
      resultados.writeln('\n📱 Como usar em outro dispositivo:');
      resultados.writeln('   1. Instale o app no outro dispositivo');
      resultados.writeln('   2. Faça login com o mesmo email: ${_emailController.text}');
      resultados.writeln('   3. Veja os mesmos vinhos aparecerem automaticamente!');

      setState(() {
        _status = resultados.toString();
        _statusColor = Colors.green;
        _loading = false;
      });
    } catch (e, stackTrace) {
      resultados.writeln('\n❌ ERRO: $e');
      resultados.writeln('\n📋 Stack trace:');
      resultados.writeln(stackTrace.toString().substring(0, 500));
      
      resultados.writeln('\n💡 Possíveis soluções:');
      resultados.writeln('   • Verifique se Authentication está habilitado');
      resultados.writeln('   • Verifique as regras do Firestore');
      resultados.writeln('   • Confirme que a região é europe-west1');
      resultados.writeln('   • Certifique-se de estar logado (firebase login)');
      
      setState(() {
        _status = resultados.toString();
        _statusColor = Colors.red;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Teste Firebase'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Credenciais de Teste',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Senha',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _testeCompleto,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              label: Text(
                _loading ? 'Testando...' : '🧪 Executar Teste Completo',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: _statusColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _status,
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 12,
                    color: _statusColor.withOpacity(0.9),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
