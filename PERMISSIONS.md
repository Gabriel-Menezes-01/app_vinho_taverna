# Configuração de Permissões

## Android

Para usar a câmera e galeria no Android, as permissões já estão configuradas automaticamente pelo plugin `image_picker`. No entanto, você pode verificar se o arquivo `android/app/src/main/AndroidManifest.xml` contém:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

## iOS

Para iOS, você precisa adicionar as seguintes entradas no arquivo `ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Precisamos acessar sua galeria para selecionar fotos dos vinhos</string>
<key>NSCameraUsageDescription</key>
<string>Precisamos acessar sua câmera para tirar fotos dos vinhos</string>
<key>NSMicrophoneUsageDescription</key>
<string>Precisamos acessar o microfone para gravar vídeos</string>
```

## Web

Para web, não são necessárias permissões especiais, mas algumas funcionalidades podem ter limitações.

## Notas Importantes

- **Android 10+**: O acesso ao storage é gerenciado automaticamente pelo `image_picker`
- **iOS 14+**: Os usuários podem escolher dar acesso limitado à biblioteca de fotos
- As permissões serão solicitadas automaticamente quando o usuário tentar usar a câmera ou galeria pela primeira vez
