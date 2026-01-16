# Taverna dos Vinhos 🍷

Aplicativo Flutter para gerenciamento de vinhos com avaliações pessoais.

## 📱 Funcionalidades

- ✅ Lista de vinhos cadastrados
- ✅ Adicionar novos vinhos com foto, nome, preço, descrição e avaliação
- ✅ Editar vinhos existentes
- ✅ Excluir vinhos
- ✅ Visualizar detalhes completos de cada vinho
- ✅ Upload de fotos via câmera ou galeria
- ✅ Armazenamento local com Hive
- ✅ Interface moderna e intuitiva

## 🏗️ Estrutura do Projeto

```
lib/
├── main.dart                      # Ponto de entrada do app
├── models/
│   ├── wine.dart                  # Modelo de dados Wine
│   └── wine.g.dart                # Adaptador Hive gerado
├── services/
│   └── wine_service.dart          # Serviço de armazenamento (CRUD)
└── screens/
    ├── home_screen.dart           # Tela principal (lista de vinhos)
    ├── wine_detail_screen.dart    # Tela de detalhes do vinho
    └── add_edit_wine_screen.dart  # Tela de adicionar/editar vinho
```

## 🚀 Como Executar

1. Certifique-se de ter o Flutter instalado (versão 3.10.7 ou superior)

2. Clone o repositório e navegue até a pasta do projeto

3. Instale as dependências:
```bash
flutter pub get
```

4. Execute o app:
```bash
flutter run
```

## 📦 Dependências Principais

- **hive & hive_flutter**: Banco de dados local leve e rápido
- **image_picker**: Seleção de imagens da câmera ou galeria
- **path_provider**: Acesso aos diretórios do dispositivo

## 💡 Como Usar

1. **Adicionar um vinho**: 
   - Toque no botão flutuante (+) na tela principal
   - Preencha os dados do vinho
   - Toque no ícone da câmera para adicionar uma foto
   - Selecione se o vinho é "Bom" ou "Ruim"
   - Toque em "Adicionar"

2. **Ver detalhes**:
   - Toque em qualquer vinho da lista
   - Visualize foto em destaque, preço, descrição e avaliação

3. **Editar um vinho**:
   - Na tela de detalhes, toque no ícone de editar (lápis)
   - Modifique os dados desejados
   - Toque em "Atualizar"

4. **Excluir um vinho**:
   - Na tela de detalhes, toque no ícone de lixeira
   - Confirme a exclusão

## 🎨 Características da Interface

- Tema personalizado com cores de vinho
- Cards modernos com elevação
- Animação Hero nas transições de imagem
- Estado vazio amigável
- Diálogos de confirmação
- Feedback visual com SnackBars

## 📄 Licença

Este projeto é de código aberto e está disponível sob a licença MIT.

