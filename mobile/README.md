# RUMAR — Flutter

Primeiro protótipo móvel/web da aplicação para profissionais de instalações.

## Desenvolvimento local

```bash
flutter pub get
flutter run
```

Para testar no browser:

```bash
flutter run -d chrome
```

## Verificações

```bash
flutter analyze
flutter test
```

## Build web para Vercel ou GitHub Pages

```bash
flutter build web --release --base-href "/"
```

Publicar a pasta `build/web`. O `vercel.json` incluído mantém a navegação interna a funcionar como SPA.

## Próximo passo técnico

Substituir os dados locais de demonstração por Supabase: autenticação, organizações, clientes, trabalhos, compromissos, ficheiros e auditoria. A UI foi construída sem dependências externas para permitir validar o fluxo antes de ligar custos de backend e IA.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
