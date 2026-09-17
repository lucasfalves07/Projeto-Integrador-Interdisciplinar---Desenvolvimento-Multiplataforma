# Projeto Integrador Interdisciplinar — Desenvolvimento Multiplataforma 📚💻

Site pessoal de professor para compartilhamento de materiais, notas e mensagens, desenvolvido para a escola Poliedro. 🏫

## Objetivo

O projeto tem como objetivo o desenvolvimento de uma plataforma pessoal para professores, com foco em compartilhamento de conteúdos, envio de mensagens individuais e divulgação segura de notas. A aplicação é multiplataforma (web, desktop e mobile), com autenticação por RA e senha, respeitando princípios de segurança, privacidade e usabilidade. 📲

## Stack

- **Flutter / Dart** — app multiplataforma (Android, iOS, Web, Windows, Linux, macOS)
- **Firebase** — Auth, Cloud Firestore, Storage, Cloud Messaging
- **Hive** — cache/armazenamento local
- **Provider** + **go_router** — estado e navegação

## Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.35 ou superior (o projeto usa Dart `^3.9.2`)
- Um editor com suporte a Flutter (VS Code ou Android Studio)
- Para rodar em Android: Android Studio + um emulador ou aparelho físico com depuração USB ativada
- Para rodar em iOS/macOS: Xcode (apenas em macOS)
- Para rodar na Web: Google Chrome

Verifique se o ambiente está pronto com:

```bash
flutter doctor
```

## Como rodar o projeto

1. Clone o repositório:

   ```bash
   git clone https://github.com/lucasfalves07/Projeto_Flutter.git
   cd Projeto_Flutter
   ```

2. Instale as dependências:

   ```bash
   flutter pub get
   ```

3. Veja quais dispositivos/plataformas estão disponíveis:

   ```bash
   flutter devices
   ```

4. Rode o app escolhendo o destino desejado:

   ```bash
   # Web (Chrome)
   flutter run -d chrome

   # Android (emulador ou aparelho conectado)
   flutter run -d android

   # Desktop (Windows, Linux ou macOS)
   flutter run -d windows   # ou -d linux / -d macos
   ```

   Sem o parâmetro `-d`, o Flutter pergunta interativamente qual dispositivo usar.

> **Firebase:** as chaves de configuração (`lib/firebase_options.dart`) já estão versionadas no projeto, então não é necessário rodar `flutterfire configure` para testar localmente. Caso vá publicar o app ou usar seu próprio projeto Firebase, gere suas próprias credenciais com a [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup) e substitua esse arquivo.

## Gerando builds de produção

```bash
flutter build web            # gera em build/web
flutter build apk            # gera um .apk em build/app/outputs
flutter build windows        # ou build linux / build macos
```

## Testes

```bash
flutter test
```

## Popular o banco de dados (opcional)

O projeto inclui scripts auxiliares para popular o Firestore com dados de exemplo (turmas, alunos, atividades etc.):

```bash
dart run lib/utils/seed.dart
```

## Estrutura do projeto

```
lib/
├── components/   # Widgets reutilizáveis (botões, cards, inputs, gráficos...)
├── pages/        # Telas do app (login, dashboard, boletim, mensagens...)
├── services/     # Integração com Firebase Auth/Firestore
├── theme/        # Tema claro/escuro
├── utils/        # Funções utilitárias e seed de dados
├── router.dart   # Rotas (go_router)
└── main.dart     # Ponto de entrada da aplicação

firebase/         # Regras de segurança do Firestore e Storage
android/ ios/ web/ windows/ linux/ macos/   # Configurações específicas de cada plataforma
```
