# pbl6_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## AI (DeepSeek) configuration

This app can call an OpenAI-compatible Chat Completions API for AI analysis. Configure it using Dart defines to avoid hardcoding secrets.

1) Local defines file (recommended for development)

Create `dart-defines.local.json` in the project root (already ignored by .gitignore) with:

{
	"DEEPSEEK_API_KEY": "hf_...",
	"DEEPSEEK_BASE_URL": "https://router.huggingface.co/v1",
	"DEEPSEEK_MODEL": "deepseek-ai/DeepSeek-V3.1:novita"
}

Run the app using the file:

flutter run --dart-define-from-file=dart-defines.local.json

2) Or pass defines inline:

flutter run `
	--dart-define=DEEPSEEK_API_KEY=hf_xxx `
	--dart-define=DEEPSEEK_BASE_URL=https://router.huggingface.co/v1 `
	--dart-define=DEEPSEEK_MODEL=deepseek-ai/DeepSeek-V3.1:novita

Notes:
- `DEEPSEEK_API_KEY` is required. The other two are optional (defaults point to the DeepSeek API and `deepseek-chat`).
- Never commit real API keys. The .gitignore already excludes `dart-defines.local.json`.
