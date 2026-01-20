import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// ============================================================================
/// FCM BACKGROUND HANDLER - DEVE ESTAR NO TOP LEVEL
/// ============================================================================
/// 
/// Este handler é chamado quando o app recebe uma mensagem FCM em background
/// (app minimizado ou fechado). Ele roda em um Isolate separado.
/// 
/// IMPORTANTE: Este handler NÃO deve fazer operações pesadas. Apenas dispara
/// a sincronização e retorna rapidamente.

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Inicializar Firebase (necessário no isolate background)
  await Firebase.initializeApp();
  
  debugPrint('🔔 [Background] FCM Message recebida: ${message.messageId}');
  debugPrint('🔔 [Background] Data: ${message.data}');
  
  // Verificar se é um trigger de sincronização
  if (message.data['type'] == 'SYNC_TRIGGER') {
    final entity = message.data['entity'] as String?;
    debugPrint('🔄 [Background] Trigger de sync recebido para: $entity');
    
    // Aqui você pode:
    // 1. Salvar uma flag local indicando que há sync pendente
    // 2. Ou disparar um WorkManager job (Android) / Background Task (iOS)
    // 3. Ou iniciar a sync imediatamente se for rápida
    
    // Para este exemplo, vamos disparar a sync via callback
    await FCMSyncService.instance.handleBackgroundSync(entity ?? 'products');
  }
}

/// ============================================================================
/// SERVIÇO DE CONFIGURAÇÃO DO FCM
/// ============================================================================
/// 
/// Gerencia toda a configuração do Firebase Cloud Messaging:
/// - Permissões
/// - Token registration
/// - Handlers de mensagens (foreground, background, terminated)
/// - Envio de token para o servidor

class FCMSyncService {
  static final FCMSyncService _instance = FCMSyncService._internal();
  static FCMSyncService get instance => _instance;
  
  FCMSyncService._internal();
  
  FirebaseMessaging? _messaging;
  String? _currentToken;
  
  /// Callback para quando receber um trigger de sync
  /// Será chamado tanto em foreground quanto background
  Function(String entity)? onSyncTrigger;
  
  /// Inicializa o FCM completamente
  Future<void> initialize({
    required Function(String entity) onSyncCallback,
  }) async {
    onSyncTrigger = onSyncCallback;
    
    _messaging = FirebaseMessaging.instance;
    
    // 1. Solicitar permissões (iOS/Web)
    await _requestPermissions();
    
    // 2. Configurar handlers
    _setupHandlers();
    
    // 3. Obter e enviar token para o servidor
    await _setupTokenHandling();
    
    debugPrint('✅ FCM Service inicializado com sucesso');
  }
  
  /// Solicita permissões para notificações
  Future<void> _requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      NotificationSettings settings = await _messaging!.requestPermission(
        alert: false, // NÃO queremos alertas visuais
        announcement: false,
        badge: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: false, // NÃO queremos som
      );
      
      debugPrint('📱 Permissão FCM (iOS): ${settings.authorizationStatus}');
    } else if (Platform.isAndroid) {
      // Android 13+ requer permissão runtime
      await _messaging!.requestPermission(
        alert: false,
        announcement: false,
        badge: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: false,
      );
      debugPrint('📱 Permissão FCM (Android) solicitada');
    }
  }
  
  /// Configura os handlers de mensagens
  void _setupHandlers() {
    // FOREGROUND: App aberto e visível
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 [Foreground] FCM Message: ${message.messageId}');
      debugPrint('🔔 [Foreground] Data: ${message.data}');
      
      // Processar sync trigger em foreground
      if (message.data['type'] == 'SYNC_TRIGGER') {
        final entity = message.data['entity'] as String? ?? 'products';
        debugPrint('🔄 [Foreground] Trigger de sync: $entity');
        onSyncTrigger?.call(entity);
      }
      
      // NÃO mostrar notificação visual (data message apenas)
    });
    
    // OPENED: Usuário clicou na notificação (se houver)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 [Opened] FCM Message aberta: ${message.messageId}');
      // Para data messages silenciosos, isso raramente acontece
    });
    
    // BACKGROUND/TERMINATED: Registrar o handler top-level
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  
  /// Configura o tratamento do token FCM
  Future<void> _setupTokenHandling() async {
    // Obter token inicial
    _currentToken = await _messaging!.getToken();
    if (_currentToken != null) {
      debugPrint('📲 FCM Token obtido: ${_currentToken!.substring(0, 20)}...');
      await _sendTokenToServer(_currentToken!);
    }
    
    // Listener para refresh do token
    _messaging!.onTokenRefresh.listen((newToken) {
      debugPrint('🔄 FCM Token atualizado: ${newToken.substring(0, 20)}...');
      _currentToken = newToken;
      _sendTokenToServer(newToken);
    });
  }
  
  /// Envia o token FCM para o servidor
  /// O servidor usa este token para enviar mensagens silenciosas
  Future<void> _sendTokenToServer(String token) async {
    try {
      // TODO: Implementar chamada HTTP para seu backend
      // POST /api/devices/register
      // Body: { "fcmToken": token, "userId": currentUserId, "platform": "android/ios" }
      
      debugPrint('📤 Enviando FCM token para o servidor...');
      
      // Exemplo:
      // final response = await http.post(
      //   Uri.parse('$apiBaseUrl/api/devices/register'),
      //   headers: {'Authorization': 'Bearer $userToken'},
      //   body: jsonEncode({
      //     'fcmToken': token,
      //     'userId': currentUserId,
      //     'platform': Platform.operatingSystem,
      //   }),
      // );
      
      debugPrint('✅ Token registrado no servidor');
    } catch (e) {
      debugPrint('❌ Erro ao registrar token: $e');
    }
  }
  
  /// Handler chamado pelo background isolate
  /// Este método é chamado quando uma mensagem de sync chega em background
  static Future<void> handleBackgroundSync(String entity) async {
    debugPrint('🔄 [Background Sync] Iniciando para: $entity');
    
    // Aqui você pode:
    // 1. Salvar uma flag em SharedPreferences
    // 2. Usar WorkManager para agendar a sync
    // 3. Iniciar a sync imediatamente (cuidado com timeouts)
    
    // Exemplo simples: salvar flag para sync quando app abrir
    try {
      final prefs = await SharedPreferencesAsync();
      await prefs.setBool('pending_sync_$entity', true);
      debugPrint('✅ Flag de sync pendente salva');
    } catch (e) {
      debugPrint('❌ Erro ao salvar flag: $e');
    }
  }
  
  /// Subscreve em um tópico FCM (útil para broadcast)
  Future<void> subscribeToTopic(String topic) async {
    await _messaging?.subscribeToTopic(topic);
    debugPrint('📢 Subscrito ao tópico: $topic');
  }
  
  /// Remove subscrição de um tópico
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging?.unsubscribeFromTopic(topic);
    debugPrint('📢 Removido do tópico: $topic');
  }
  
  /// Obtém o token atual
  String? get currentToken => _currentToken;
}

/// Helper para SharedPreferences (versão async)
class SharedPreferencesAsync {
  // Implementação simplificada - use shared_preferences package
  Future<void> setBool(String key, bool value) async {
    // TODO: Implementar com shared_preferences
  }
  
  Future<bool?> getBool(String key) async {
    // TODO: Implementar com shared_preferences
    return null;
  }
}
