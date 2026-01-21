import 'package:cloud_firestore/cloud_firestore.dart';

/// Serviço para gerenciar operações do Firestore
/// 
/// Centraliza todas as operações de banco de dados para facilitar
/// manutenção e reutilização de código
class FirestoreService {
  // Instância do Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Nomes das coleções
  static const String vinhos = 'vinhos';
  static const String pedidos = 'pedidos';
  static const String clientes = 'clientes';
  static const String categorias = 'categorias';

  /// Adiciona um documento a uma coleção no Firestore
  /// 
  /// [nomeColecao] - Nome da coleção onde o documento será adicionado
  /// [dados] - Map com os dados do documento
  /// 
  /// Retorna o ID do documento criado em caso de sucesso,
  /// ou null em caso de erro
  Future<String?> adicionarDocumento({
    required String nomeColecao,
    required Map<String, dynamic> dados,
  }) async {
    try {
      // Adiciona timestamp de criação automaticamente
      final dadosCompletos = {
        ...dados,
        'criadoEm': FieldValue.serverTimestamp(),
        'atualizadoEm': FieldValue.serverTimestamp(),
      };

      // Obtém a referência da coleção e adiciona o documento
      final DocumentReference docRef = await _firestore
          .collection(nomeColecao)
          .add(dadosCompletos);

      // Log de sucesso
      print('✓ Documento adicionado com sucesso!');
      print('  Coleção: $nomeColecao');
      print('  ID do documento: ${docRef.id}');
      print('  Dados: $dados');

      return docRef.id;
    } on FirebaseException catch (e) {
      // Erro específico do Firebase
      print('✗ Erro do Firebase ao adicionar documento:');
      print('  Código: ${e.code}');
      print('  Mensagem: ${e.message}');
      return null;
    } catch (e) {
      // Outros erros
      print('✗ Erro desconhecido ao adicionar documento:');
      print('  Erro: $e');
      return null;
    }
  }

  /// Adiciona um vinho à coleção 'vinhos'
  /// 
  /// Método específico para facilitar a adição de vinhos
  Future<String?> adicionarVinho({
    required String nome,
    required double preco,
    String? descricao,
    String? categoria,
    int estoque = 0,
    String? imagem,
    bool ativo = true,
  }) async {
    final dados = {
      'nome': nome,
      'preco': preco,
      if (descricao != null) 'descricao': descricao,
      if (categoria != null) 'categoria': categoria,
      'estoque': estoque,
      if (imagem != null) 'imagem': imagem,
      'ativo': ativo,
    };

    return await adicionarDocumento(
      nomeColecao: vinhos,
      dados: dados,
    );
  }

  /// Adiciona um pedido à coleção 'pedidos'
  Future<String?> adicionarPedido({
    required String clienteId,
    required List<Map<String, dynamic>> itens,
    required double total,
    String status = 'pendente',
  }) async {
    final dados = {
      'clienteId': clienteId,
      'itens': itens,
      'total': total,
      'status': status,
      'data': Timestamp.now(),
    };

    return await adicionarDocumento(
      nomeColecao: pedidos,
      dados: dados,
    );
  }

  /// Adiciona um cliente à coleção 'clientes'
  Future<String?> adicionarCliente({
    required String nome,
    required String email,
    String? telefone,
    String? endereco,
  }) async {
    final dados = {
      'nome': nome,
      'email': email,
      if (telefone != null) 'telefone': telefone,
      if (endereco != null) 'endereco': endereco,
    };

    return await adicionarDocumento(
      nomeColecao: clientes,
      dados: dados,
    );
  }

  /// Atualiza um documento existente
  Future<bool> atualizarDocumento({
    required String nomeColecao,
    required String documentoId,
    required Map<String, dynamic> dados,
  }) async {
    try {
      // Adiciona timestamp de atualização
      final dadosCompletos = {
        ...dados,
        'atualizadoEm': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(nomeColecao)
          .doc(documentoId)
          .update(dadosCompletos);

      print('✓ Documento atualizado com sucesso!');
      print('  Coleção: $nomeColecao');
      print('  ID: $documentoId');

      return true;
    } on FirebaseException catch (e) {
      print('✗ Erro do Firebase ao atualizar documento:');
      print('  Código: ${e.code}');
      print('  Mensagem: ${e.message}');
      return false;
    } catch (e) {
      print('✗ Erro ao atualizar documento: $e');
      return false;
    }
  }

  /// Deleta um documento
  Future<bool> deletarDocumento({
    required String nomeColecao,
    required String documentoId,
  }) async {
    try {
      await _firestore.collection(nomeColecao).doc(documentoId).delete();

      print('✓ Documento deletado com sucesso!');
      print('  Coleção: $nomeColecao');
      print('  ID: $documentoId');

      return true;
    } on FirebaseException catch (e) {
      print('✗ Erro do Firebase ao deletar documento:');
      print('  Código: ${e.code}');
      print('  Mensagem: ${e.message}');
      return false;
    } catch (e) {
      print('✗ Erro ao deletar documento: $e');
      return false;
    }
  }

  /// Busca um documento por ID
  Future<Map<String, dynamic>?> buscarDocumentoPorId({
    required String nomeColecao,
    required String documentoId,
  }) async {
    try {
      final doc = await _firestore
          .collection(nomeColecao)
          .doc(documentoId)
          .get();

      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }

      print('⚠ Documento não encontrado');
      return null;
    } catch (e) {
      print('✗ Erro ao buscar documento: $e');
      return null;
    }
  }

  /// Busca todos os documentos de uma coleção
  Future<List<Map<String, dynamic>>> buscarTodosDocumentos({
    required String nomeColecao,
    int? limite,
  }) async {
    try {
      Query query = _firestore.collection(nomeColecao);

      if (limite != null) {
        query = query.limit(limite);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();
    } catch (e) {
      print('✗ Erro ao buscar documentos: $e');
      return [];
    }
  }

  /// Stream para ouvir mudanças em tempo real de uma coleção
  Stream<List<Map<String, dynamic>>> ouvirColecao({
    required String nomeColecao,
    int? limite,
  }) {
    Query query = _firestore.collection(nomeColecao);

    if (limite != null) {
      query = query.limit(limite);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();
    });
  }
}
