# 🍷 Adega de Vinhos - Nova Funcionalidade

## O que foi adicionado

### 1. **Nova Tela: Adega (AdegaScreen)**
   - Localização: `lib/screens/adega_screen.dart`
   - Permite adicionar vinhos com os seguintes campos:
     - **Nome** do vinho
     - **Tipo**: Tinto 🔴 | Branco ⚪ | Rosé 🌸 | Verde 🟢
     - **Região**: Douro, Algarve, Dão, etc.
     - **Ano** de colheita
     - **Preço** (em €)
     - **Descrição** (opcional)

### 2. **Botão no Menu**
   - Novo item no menu dropdown: **"🍷 Adega"**
   - Localizado entre "Adicionar vinho" e "Vendas do Mês"
   - Clique para abrir a tela de adega

### 3. **Fluxo de Uso**
   ```
   Menu (≡) → Clique em "🍷 Adega"
     ↓
   Preencha os campos do vinho
     ↓
   Clique em "Adicionar à Adega"
     ↓
   Vinho salvo no Firestore + SQLite
     ↓
   Volta automaticamente para a lista de vinhos
   ```

### 4. **Campos do Formulário**

| Campo | Tipo | Obrigatório | Descrição |
|-------|------|-------------|-----------|
| Nome | Texto | ✅ | Nome do vinho (ex: Quinta dos Sonhos) |
| Tipo | Dropdown | ✅ | Tinto / Branco / Rosé / Verde |
| Região | Dropdown | ✅ | Douro, Algarve, Dão, Minho, etc. |
| Ano | Número | ✅ | Ano de colheita (1900-2026) |
| Preço | Decimal | ✅ | Preço em euros (ex: 25.50) |
| Descrição | Texto | ❌ | Notas de degustação, características |

### 5. **Sincronização**
   - Vinho salvo automaticamente no **Firestore** ☁️
   - Também salvo em cache local (**SQLite**)
   - Sincronizado entre todos os dispositivos
   - Email: mesmo usuário, mesmos vinhos

## Como Testar

### 1. Abrir Adega
```
1. Clique no ≡ (menu) no canto superior direito
2. Clique em "🍷 Adega"
3. Tela com formulário abre
```

### 2. Adicionar Vinho
```
1. Preencha:
   - Nome: "Douro Premium 2020"
   - Tipo: Tinto
   - Região: Douro
   - Ano: 2020
   - Preço: 35.00
   - Descrição: "Taninos suaves, frutas vermelhas"

2. Clique "Adicionar à Adega"
3. Mensagem de sucesso aparece ✅
4. Volta automaticamente para a lista
```

### 3. Verificar Sincronização
```
1. Vinho aparece na lista de vinhos
2. Vá ao Console Firebase
3. Firestore Database → /users/{uid}/wines
4. Vinho está lá com todos os dados ✅
```

### 4. Testar em Outro Dispositivo
```
1. Instale o app em Android/iPhone
2. Faça login com MESMO EMAIL
3. Vinho que criou no Windows aparece automaticamente! 🎉
```

## Mudanças nos Arquivos

### `lib/screens/home_screen.dart`
- ✅ Import da AdegaScreen
- ✅ Função `_openAdegaScreen()`
- ✅ Novo item no menu: "🍷 Adega"
- ✅ Recarrega vinhos ao voltar da adega

### `pubspec.yaml`
- ✅ Dependência `uuid: ^4.0.0` (gera IDs únicos)

### Novo arquivo: `lib/screens/adega_screen.dart`
- ✅ Tela completa de adicionar vinhos
- ✅ Validação de campos
- ✅ Salva no Firestore + SQLite

## Funcionalidades Extras

✨ **Emojis nos tipos de vinho**
- 🔴 Tinto
- ⚪ Branco
- 🌸 Rosé
- 🟢 Verde

✨ **Validação automática**
- Campo vazio? Aviso
- Ano inválido? Aviso
- Preço não é número? Aviso

✨ **Feedback visual**
- ✅ Mensagem verde ao adicionar
- ❌ Mensagem vermelha se erro
- Loading spinner enquanto salva

## Próximos Passos

- [ ] Testar adicionar vinho na adega
- [ ] Verificar sincronização no Firestore
- [ ] Testar em outro dispositivo
- [ ] Editar/deletar vinhos da adega
- [ ] Adicionar foto do vinho
- [ ] Classificação (estrelas)
