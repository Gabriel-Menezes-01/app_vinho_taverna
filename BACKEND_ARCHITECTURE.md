# 🏗️ ARQUITETURA BACKEND - Sincronização Multi-Dispositivo

## 📋 Visão Geral

Este documento descreve a arquitetura backend necessária para suportar sincronização em tempo real entre múltiplos dispositivos usando Firebase Cloud Messaging (FCM) como trigger.

---

## 🗄️ 1. SCHEMA DO BANCO DE DADOS

### Tabela: `products`

```sql
CREATE TABLE products (
  -- Identificação
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Dados do produto
  name VARCHAR(255) NOT NULL,
  price DECIMAL(10, 2) NOT NULL,
  description TEXT,
  image_path VARCHAR(500),
  region VARCHAR(100) NOT NULL,
  wine_type VARCHAR(50) NOT NULL,
  quantity INTEGER DEFAULT 0,
  
  -- Timestamps para Delta Sync (CRÍTICO)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Controle de versão para conflict resolution
  version INTEGER DEFAULT 1,
  
  -- Soft delete
  is_deleted BOOLEAN DEFAULT FALSE,
  
  -- Índices
  INDEX idx_user_id (user_id),
  INDEX idx_updated_at (updated_at),  -- CRÍTICO para delta sync
  INDEX idx_user_updated (user_id, updated_at),  -- Composto para queries eficientes
  INDEX idx_region (region)
);

-- Trigger para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  NEW.version = OLD.version + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

### Tabela: `user_devices`

```sql
CREATE TABLE user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Token FCM para este dispositivo
  fcm_token VARCHAR(500) NOT NULL UNIQUE,
  
  -- Informações do dispositivo
  device_id VARCHAR(255) NOT NULL,
  device_name VARCHAR(255),
  platform VARCHAR(50),  -- 'android', 'ios', 'web'
  app_version VARCHAR(50),
  
  -- Controle
  is_active BOOLEAN DEFAULT TRUE,
  last_seen_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Índices
  INDEX idx_user_id (user_id),
  INDEX idx_fcm_token (fcm_token),
  INDEX idx_active_devices (user_id, is_active)
);
```

---

## 🚀 2. API ENDPOINTS

### 2.1 Endpoint de Delta Sync

**GET** `/api/products/sync`

Query Parameters:
- `since` (opcional): ISO 8601 timestamp. Se omitido, retorna todos.

```typescript
// Node.js + Express exemplo
router.get('/api/products/sync', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const since = req.query.since;
    
    let query = `
      SELECT * FROM products
      WHERE user_id = $1
      AND is_deleted = FALSE
    `;
    
    const params = [userId];
    
    // Delta Sync: apenas produtos modificados após 'since'
    if (since) {
      query += ` AND updated_at > $2`;
      params.push(since);
    }
    
    query += ` ORDER BY updated_at ASC`;
    
    const result = await db.query(query, params);
    
    res.json({
      success: true,
      products: result.rows,
      syncedAt: new Date().toISOString(),
      count: result.rows.length,
    });
    
  } catch (error) {
    console.error('Erro no delta sync:', error);
    res.status(500).json({ error: 'Erro ao sincronizar' });
  }
});
```

### 2.2 Endpoint de Metadata

**GET** `/api/products/sync/metadata`

Retorna informações sobre o dataset completo (para sync inicial)

```typescript
router.get('/api/products/sync/metadata', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    
    const result = await db.query(
      `SELECT COUNT(*) as total FROM products 
       WHERE user_id = $1 AND is_deleted = FALSE`,
      [userId]
    );
    
    res.json({
      total_products: parseInt(result.rows[0].total),
      page_size: 1000,  // Tamanho recomendado por página
      last_updated: await getLastProductUpdate(userId),
    });
    
  } catch (error) {
    res.status(500).json({ error: 'Erro ao obter metadata' });
  }
});
```

### 2.3 Endpoint de Atualização

**PUT** `/api/products/:id`

```typescript
router.put('/api/products/:id', authenticate, async (req, res) => {
  try {
    const productId = req.params.id;
    const userId = req.user.id;
    const updateData = req.body;
    
    // 1. Atualizar produto no banco
    const result = await db.query(
      `UPDATE products 
       SET name = $1, price = $2, description = $3, 
           region = $4, wine_type = $5, quantity = $6
       WHERE id = $7 AND user_id = $8
       RETURNING *`,
      [
        updateData.name,
        updateData.price,
        updateData.description,
        updateData.region,
        updateData.wineType,
        updateData.quantity,
        productId,
        userId,
      ]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Produto não encontrado' });
    }
    
    const updatedProduct = result.rows[0];
    
    // 2. DISPARAR FCM para outros dispositivos do usuário
    await triggerSyncForUserDevices(userId, 'products', {
      productId: productId,
      action: 'updated',
    });
    
    res.json({
      success: true,
      product: updatedProduct,
    });
    
  } catch (error) {
    console.error('Erro ao atualizar produto:', error);
    res.status(500).json({ error: 'Erro ao atualizar' });
  }
});
```

### 2.4 Registro de Dispositivo

**POST** `/api/devices/register`

```typescript
router.post('/api/devices/register', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const { fcmToken, deviceId, platform, deviceName } = req.body;
    
    // Upsert: atualizar se existir, inserir se não existir
    await db.query(
      `INSERT INTO user_devices 
       (user_id, fcm_token, device_id, platform, device_name, last_seen_at)
       VALUES ($1, $2, $3, $4, $5, NOW())
       ON CONFLICT (fcm_token) 
       DO UPDATE SET 
         last_seen_at = NOW(),
         is_active = TRUE`,
      [userId, fcmToken, deviceId, platform, deviceName]
    );
    
    res.json({ success: true });
    
  } catch (error) {
    console.error('Erro ao registrar dispositivo:', error);
    res.status(500).json({ error: 'Erro ao registrar' });
  }
});
```

---

## 🔔 3. LÓGICA DO FCM TRIGGER

### 3.1 Função de Disparo

```typescript
import admin from 'firebase-admin';

// Inicializar Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert({
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
  }),
});

/**
 * Dispara notificação silenciosa para todos os dispositivos
 * do usuário, EXCETO o dispositivo que originou a mudança
 */
async function triggerSyncForUserDevices(
  userId: string,
  entity: string,
  metadata?: Record<string, any>
) {
  try {
    // 1. Buscar todos os dispositivos ativos do usuário
    const devicesResult = await db.query(
      `SELECT fcm_token FROM user_devices 
       WHERE user_id = $1 AND is_active = TRUE`,
      [userId]
    );
    
    if (devicesResult.rows.length === 0) {
      console.log('Nenhum dispositivo ativo encontrado');
      return;
    }
    
    const tokens = devicesResult.rows.map(row => row.fcm_token);
    
    console.log(`📤 Enviando FCM para ${tokens.length} dispositivos`);
    
    // 2. Criar mensagem de dados (SEM notificação visual)
    const message: admin.messaging.MulticastMessage = {
      tokens: tokens,
      
      // Data message - NÃO gera notificação visual
      data: {
        type: 'SYNC_TRIGGER',
        entity: entity,
        timestamp: new Date().toISOString(),
        ...metadata,
      },
      
      // Configurações para Android
      android: {
        priority: 'high',  // Alta prioridade para acordar app
        // NÃO incluir 'notification' - apenas data
      },
      
      // Configurações para iOS/APNs
      apns: {
        headers: {
          'apns-priority': '10',  // Alta prioridade
        },
        payload: {
          aps: {
            'content-available': 1,  // Background update
            // NÃO incluir 'alert' ou 'sound'
          },
        },
      },
    };
    
    // 3. Enviar mensagem
    const response = await admin.messaging().sendMulticast(message);
    
    console.log(`✅ FCM enviado: ${response.successCount} sucesso, ${response.failureCount} falhas`);
    
    // 4. Processar falhas (tokens inválidos)
    if (response.failureCount > 0) {
      const failedTokens: string[] = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          failedTokens.push(tokens[idx]);
          console.error(`❌ Erro no token ${tokens[idx]}: ${resp.error}`);
        }
      });
      
      // Remover tokens inválidos do banco
      await removeInvalidTokens(failedTokens);
    }
    
  } catch (error) {
    console.error('❌ Erro ao enviar FCM:', error);
    throw error;
  }
}

/**
 * Remove tokens FCM inválidos do banco
 */
async function removeInvalidTokens(tokens: string[]) {
  if (tokens.length === 0) return;
  
  await db.query(
    `UPDATE user_devices 
     SET is_active = FALSE 
     WHERE fcm_token = ANY($1)`,
    [tokens]
  );
  
  console.log(`🗑️  ${tokens.length} tokens inválidos marcados como inativos`);
}
```

---

## 🔐 4. SEGURANÇA E AUTENTICAÇÃO

### 4.1 Middleware de Autenticação

```typescript
import jwt from 'jsonwebtoken';

const authenticate = (req, res, next) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ error: 'Token não fornecido' });
    }
    
    const decoded = jwt.verify(token, process.env.JWT_SECRET!);
    req.user = decoded;
    next();
    
  } catch (error) {
    res.status(401).json({ error: 'Token inválido' });
  }
};
```

### 4.2 Rate Limiting

```typescript
import rateLimit from 'express-rate-limit';

const syncLimiter = rateLimit({
  windowMs: 1 * 60 * 1000,  // 1 minuto
  max: 30,  // Máximo 30 requests por minuto
  message: 'Muitas requisições de sync, tente novamente mais tarde',
});

router.get('/api/products/sync', authenticate, syncLimiter, async (req, res) => {
  // ...
});
```

---

## 📊 5. MONITORAMENTO E LOGS

### 5.1 Logging Estruturado

```typescript
import winston from 'winston';

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.File({ filename: 'sync-error.log', level: 'error' }),
    new winston.transports.File({ filename: 'sync-combined.log' }),
  ],
});

// Log de sync
logger.info('Delta sync executed', {
  userId,
  since,
  productsCount: result.rows.length,
  duration: Date.now() - startTime,
});
```

### 5.2 Métricas

```typescript
// Exemplo com Prometheus
import promClient from 'prom-client';

const syncCounter = new promClient.Counter({
  name: 'sync_requests_total',
  help: 'Total de requisições de sync',
  labelNames: ['user_id', 'status'],
});

const syncDuration = new promClient.Histogram({
  name: 'sync_duration_seconds',
  help: 'Duração das requisições de sync',
  buckets: [0.1, 0.5, 1, 2, 5, 10],
});
```

---

## 🚀 6. DEPLOY E INFRAESTRUTURA

### 6.1 Docker Compose

```yaml
version: '3.8'

services:
  api:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/mydb
      - FIREBASE_PROJECT_ID=your-project
      - FIREBASE_CLIENT_EMAIL=service-account@project.iam.gserviceaccount.com
      - FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...
      - JWT_SECRET=your-secret
    depends_on:
      - db
      - redis
  
  db:
    image: postgres:15
    environment:
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=mydb
    volumes:
      - postgres_data:/var/lib/postgresql/data
  
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  postgres_data:
```

### 6.2 Variáveis de Ambiente

```bash
# .env
DATABASE_URL=postgresql://localhost:5432/mydb
REDIS_URL=redis://localhost:6379
JWT_SECRET=your-jwt-secret-here
FIREBASE_PROJECT_ID=your-firebase-project
FIREBASE_CLIENT_EMAIL=your-service-account@project.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
PORT=3000
NODE_ENV=production
```

---

## 📈 7. OTIMIZAÇÕES

### 7.1 Caching com Redis

```typescript
import Redis from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);

// Cache de produtos para sync rápido
async function getCachedProducts(userId: string, since?: string) {
  const cacheKey = `products:${userId}:${since || 'all'}`;
  const cached = await redis.get(cacheKey);
  
  if (cached) {
    return JSON.parse(cached);
  }
  
  // Se não houver cache, buscar do DB e cachear
  const products = await fetchProductsFromDB(userId, since);
  await redis.setex(cacheKey, 60, JSON.stringify(products));  // Cache por 60s
  
  return products;
}
```

### 7.2 Connection Pooling

```typescript
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,  // Máximo 20 conexões simultâneas
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

---

## ✅ CHECKLIST DE IMPLEMENTAÇÃO

- [ ] Criar tabelas `products` e `user_devices`
- [ ] Implementar triggers de `updated_at`
- [ ] Criar endpoints de API (sync, metadata, update, register)
- [ ] Configurar Firebase Admin SDK
- [ ] Implementar função `triggerSyncForUserDevices`
- [ ] Adicionar autenticação JWT
- [ ] Implementar rate limiting
- [ ] Configurar logging e monitoramento
- [ ] Testar FCM em iOS e Android
- [ ] Setup Docker/Deploy
- [ ] Documentar API (Swagger/OpenAPI)

---

## 🧪 TESTES

### Teste de Delta Sync

```bash
# Criar produto
curl -X POST https://api.com/api/products \
  -H "Authorization: Bearer TOKEN" \
  -d '{"name": "Vinho Teste", "price": 50, ...}'

# Verificar se FCM foi disparado (logs)

# Delta sync em outro dispositivo
curl -X GET "https://api.com/api/products/sync?since=2026-01-19T10:00:00Z" \
  -H "Authorization: Bearer TOKEN"
```

---

**Pronto! Agora você tem uma arquitetura completa de backend para sincronização multi-dispositivo! 🚀**
