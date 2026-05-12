# Dictation Assistant

A cross-platform, fully offline dictation assistant built with Flutter and [whisper.cpp](https://github.com/ggerganov/whisper.cpp). Transcribe speech to text in **English**, **French**, and **Arabic** with local on-device inference. Optional LLM refinement via any OpenAI-compatible API.

| Feature | Status |
|---------|--------|
| Windows Desktop | ✅ Supported |
| macOS Desktop | ✅ Supported (Metal/CoreML) |
| iOS | ✅ Supported (CoreML) |
| Android | ✅ Supported (NNAPI/CPU) |
| Offline Transcription | ✅ whisper.cpp |
| LLM Refinement | ✅ OpenAI-compatible |
| Export to DOCX | ✅ |

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Getting Started](#getting-started)
3. [Whisper Model Setup](#whisper-model-setup)
4. [Platform-Specific Setup](#platform-specific-setup)
5. [LLM Configuration](#llm-configuration)
6. [Project Structure](#project-structure)
7. [Development Guide](#development-guide)
8. [Build & Distribution](#build--distribution)
9. [CI/CD Configuration](#cicd-configuration)
10. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                            │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐      │
│   │  Dictation   │  │   History    │  │      Settings        │      │
│   │    Screen    │  │   Screens    │  │       Screen         │      │
│   └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘      │
│          │                  │                      │                  │
│   ┌──────▼───────┐  ┌──────▼───────┐  ┌───────────▼──────────┐       │
│   │DictationBLoC │  │ HistoryBLoC  │  │   SettingsBLoC       │       │
│   └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘       │
└──────────┼──────────────────┼──────────────────────┼──────────────────┘
           │                  │                      │
┌──────────┼──────────────────┼──────────────────────┼──────────────────┐
│          │   APPLICATION LAYER (Use Cases)         │                   │
│          │                  │                      │                   │
│   ┌──────▼───────┐  ┌──────▼───────┐  ┌───────────▼──────────┐        │
│   │ Start/Stop   │  │ Get/Search   │  │ Update/ Download    │        │
│   │  Dictation   │  │  Sessions    │  │  Models / Settings   │        │
│   └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘        │
│          │                  │                      │                     │
├──────────┼──────────────────┼──────────────────────┼─────────────────────┤
│          │     DOMAIN LAYER (Entities + Interfaces)                     │
│   ┌──────▼───────┐  ┌──────▼───────┐  ┌───────────▼──────────┐         │
│   │ SessionEntity│  │ SettingsEntity│  │ ModelInfoEntity      │         │
│   │ ISessionRepo │  │ISettingsRepo  │  │IModelManagerRepo     │         │
│   └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘         │
├──────────┼──────────────────┼──────────────────────┼─────────────────────┤
│          │    INFRASTRUCTURE LAYER (Implementations)                     │
│   ┌──────▼───────┐  ┌──────▼───────┐  ┌───────────▼──────────┐         │
│   │ Drift/SQLite │  │ HTTP/Dio     │  │ File System          │         │
│   │ Audio/Record │  │ whisper.cpp  │  │ Clipboard            │         │
│   └──────────────┘  └──────────────┘  └──────────────────────┘         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Architecture Principles:**
- **Clean Architecture**: Domain at the center, infrastructure at the edges
- **SOLID**: Single-responsibility classes, dependency inversion via DI
- **BLoC Pattern**: Event-driven state management with unidirectional data flow
- **Dependency Injection**: `get_it` + `injectable` for zero-dependency wiring

---

## Getting Started

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Flutter SDK | >=3.24.0 | Framework |
| Dart SDK | >=3.5.0 <4.0.0 | Language |
| CMake | >=3.10 | Desktop builds |
| Xcode | >=15 | macOS/iOS builds |
| Android Studio | Latest | Android builds |
| Visual Studio | 2022 (Windows) | Windows builds |

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/your-org/dictation-assistant.git
cd dictation-assistant

# 2. Install dependencies
flutter pub get

# 3. Generate code (freezed, drift, injectable)
flutter pub run build_runner build --delete-conflicting-outputs

# 4. Download a whisper model (see Model Setup section below)
# Or bundle models by placing .bin files in assets/models/

# 5. Run on your target platform
flutter run -d macos          # macOS
flutter run -d windows        # Windows
flutter run -d <device-id>    # iOS/Android (list with `flutter devices`)
```

---

## Whisper Model Setup

### Download Models

The app uses GGML format models from the [whisper.cpp Hugging Face repository](https://huggingface.co/ggerganov/whisper.cpp).

| Model | Size | Speed | Accuracy | Best For |
|-------|------|-------|----------|----------|
| `large-v3-turbo` | ~1.6 GB | Fastest | Excellent | Desktop (default) |
| `large-v3` | ~3.1 GB | Medium | Best | High-end desktop |
| `small` | ~466 MB | Very Fast | Good | Desktop & mobile (fallback) |
| `base` | ~148 MB | Fastest | Moderate | Mobile |
| `tiny` | ~78 MB | Instant | Basic | Emergency fallback |

### Method 1: In-App Download (Recommended)

1. Open the app and go to **Settings**
2. Navigate to the **Model** section
3. Tap the download icon next to your preferred model
4. The model downloads automatically on first use

### Method 2: Manual Pre-Bundling

Download models manually to avoid first-run downloads:

```bash
# Create models directory
mkdir -p assets/models

# Download a model (example: large-v3-turbo)
curl -L -o assets/models/ggml-large-v3-turbo.bin \
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin"

# Update pubspec.yaml to include the bundled model
# Under `flutter:` -> `assets:`, ensure `assets/models/` is listed

# Rebuild
flutter pub run build_runner build
flutter build <platform>
```

### Method 3: Post-Install Manual Copy

```bash
# macOS
mkdir -p ~/Documents/DictationAssistant/models
cp ggml-large-v3-turbo.bin ~/Documents/DictationAssistant/models/

# Windows
mkdir %LOCALAPPDATA%\DictationAssistant\models
copy ggml-large-v3-turbo.bin %LOCALAPPDATA%\DictationAssistant\models\

# iOS/Android models are downloaded to app documents directory
```

---

## Platform-Specific Setup

### macOS

1. **Microphone Permission**: Add to `macos/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to record dictation audio.</string>
```

2. **Metal Acceleration** (default): The app automatically uses Metal on Apple Silicon Macs. No additional setup required.

3. **CoreML** (optional, iOS-style): Build whisper.cpp with CoreML support for potentially better performance on Apple Silicon.

4. **Entitlements**: Ensure `macos/Runner/DebugProfile.entitlements` and `Release.entitlements` include:
```xml
<key>com.apple.security.device.microphone</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>  <!-- Required for LLM refinement and model download -->
```

### Windows

1. **Microphone Permission**: Windows will prompt automatically. If disabled, go to Settings > Privacy > Microphone.

2. **Visual Studio**: Install "Desktop development with C++" workload including Windows 10/11 SDK.

3. **Build**: whisper.cpp uses CPU inference on Windows (OpenBLAS can be enabled for faster performance).

```powershell
flutter build windows --release
```

### iOS

1. **Microphone Permission**: Add to `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to record dictation audio.</string>
```

2. **CoreML**: On iOS, the app automatically uses CoreML for GPU-accelerated inference when available.

3. **Build**:
```bash
flutter build ios --release
```

### Android

1. **Permissions**: Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />  <!-- Model download & LLM -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />
```

2. **NNAPI**: On Android devices with NNAPI support, the app uses GPU acceleration automatically.

3. **ABI Support**: whisper.cpp supports: `arm64-v8a`, `armeabi-v7a`, `x86_64`. Ensure your `android/app/build.gradle` includes:
```gradle
android {
    defaultConfig {
        ndk {
            abiFilters 'arm64-v8a', 'armeabi-v7a', 'x86_64'
        }
    }
}
```

---

## LLM Configuration

The optional LLM refinement feature sends raw transcription text to any OpenAI-compatible API endpoint for structuring and cleanup.

### Supported Providers

Any API-compatible endpoint works:

| Provider | Endpoint URL | Model Example |
|----------|-------------|---------------|
| OpenAI | `https://api.openai.com` | `gpt-4o-mini` |
| Anthropic (via proxy) | Your proxy URL | `claude-3-haiku` |
| Local (Ollama) | `http://localhost:11434/v1` | `llama3.1` |
| Local (LM Studio) | `http://localhost:1234/v1` | Any loaded model |
| Azure OpenAI | Your Azure endpoint | Deployment name |

### Configuration Steps

1. Open **Settings** > **LLM Configuration**
2. Enter your endpoint URL (e.g., `https://api.openai.com` or `http://localhost:11434/v1`)
3. Enter your API token (if required)
4. Enter model name (e.g., `gpt-4o-mini`)
5. Customize the system prompt (optional)
6. Tap **Test Connection** to verify
7. Enable **Auto-refine** to automatically refine after each session (optional)

### Default System Prompt

```
Structure this dictation into clean markdown. Preserve the original language.
```

### API Request Format

The app sends requests in standard OpenAI chat completions format:

```json
POST /v1/chat/completions
{
  "model": "gpt-4o-mini",
  "messages": [
    {
      "role": "system",
      "content": "Structure this dictation into clean markdown. Preserve the original language."
    },
    {
      "role": "user",
      "content": "<your transcribed text>"
    }
  ],
  "stream": true,
  "temperature": 0.3
}
```

---

## Project Structure

```
dictation_assistant/
├── lib/
│   ├── main.dart                              # Entry point
│   ├── app.dart                               # MaterialApp, theme, navigation
│   ├── injection.dart                         # DI container setup
│   ├── injection.config.dart                  # Generated DI registrations
│   │
│   ├── core/                                  # Shared kernel
│   │   ├── constants/                         # App, audio, model, LLM constants
│   │   ├── errors/                            # Failures, exceptions
│   │   ├── usecases/                          # Base UseCase class
│   │   └── utils/                             # PCM utils, ULID, file naming
│   │
│   ├── features/
│   │   ├── dictation/                         # Main dictation feature
│   │   │   ├── domain/                        # Entities, repository interfaces, use cases
│   │   │   ├── data/                          # Models, repository implementations, datasources
│   │   │   └── presentation/                  # BLoC, pages, widgets
│   │   │
│   │   ├── history/                           # Session history feature
│   │   │   ├── domain/
│   │   │   ├── data/
│   │   │   └── presentation/
│   │   │
│   │   ├── refinement/                        # LLM refinement feature
│   │   │   ├── domain/
│   │   │   ├── data/
│   │   │   └── presentation/
│   │   │
│   │   ├── export/                            # DOCX export & clipboard
│   │   │   ├── domain/
│   │   │   ├── data/
│   │   │   └── presentation/
│   │   │
│   │   └── settings/                          # App settings & model management
│   │       ├── domain/
│   │       ├── data/
│   │       └── presentation/
│   │
│   └── services/                              # Cross-cutting services
│       ├── app_database.dart                  # Drift SQLite database
│       ├── audio_service.dart                 # Audio recording (record package)
│       ├── whisper_service.dart               # whisper.cpp FFI bindings
│       ├── chunk_processor.dart               # Chunking pipeline orchestrator
│       └── notification_service.dart          # Desktop notifications
│
├── test/                                      # Unit & widget tests
├── android/, ios/, macos/, windows/, linux/   # Platform directories
├── pubspec.yaml                               # Dependencies
├── analysis_options.yaml                      # Lint rules
├── build_scripts/                             # Build & CI scripts
└── README.md                                  # This file
```

---

## Development Guide

### Running Code Generation

After modifying any `@freezed`, `@drift`, `@injectable`, or `@retrofit` annotated classes:

```bash
# One-time build
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode (auto-regenerate on file changes)
flutter pub run build_runner watch --delete-conflicting-outputs
```

### Adding a New Feature

Follow the Clean Architecture pattern:

1. **Domain Layer**: Define entity, repository interface, and use cases
2. **Data Layer**: Implement model, repository, and datasource
3. **Presentation Layer**: Create BLoC, page, and widgets
4. **DI**: Register in `injection.config.dart`

### Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

---

## Build & Distribution

### Development Builds

```bash
# macOS
flutter build macos

# Windows
flutter build windows

# iOS (requires signing setup)
flutter build ios

# Android APK
flutter build apk

# Android App Bundle (for Play Store)
flutter build appbundle
```

### Release Builds

See `build_scripts/` directory for automated release builds.

### Windows Installer (MSIX)

```bash
# Add to pubspec.yaml:
# msix_config:
#   display_name: Dictation Assistant
#   identity_name: com.yourcompany.dictationassistant
#   msix_version: 1.0.0.0

flutter pub run msix:create
```

### macOS DMG

```bash
flutter build macos --release
create-dmg \
  --volname "Dictation Assistant" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --app-drop-link 600 185 \
  "DictationAssistant.dmg" \
  "build/macos/Build/Products/Release/Dictation Assistant.app"
```

---

## CI/CD Configuration

### GitHub Actions

The `.github/workflows/` directory contains CI configurations for automated builds.

#### `build-desktop.yml`

```yaml
name: Build Desktop

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
      - run: flutter pub get
      - run: flutter pub run build_runner build --delete-conflicting-outputs
      - run: flutter build macos --release
      - uses: actions/upload-artifact@v4
        with:
          name: dictation-assistant-macos
          path: build/macos/Build/Products/Release/*.app

  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
      - run: flutter pub get
      - run: flutter pub run build_runner build --delete-conflicting-outputs
      - run: flutter build windows --release
      - uses: actions/upload-artifact@v4
        with:
          name: dictation-assistant-windows
          path: build/windows/x64/runner/Release/

  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
      - run: flutter pub get
      - run: flutter pub run build_runner build --delete-conflicting-outputs
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v4
        with:
          name: dictation-assistant-android
          path: build/app/outputs/flutter-apk/app-release.apk
```

### Local Build Script

```bash
#!/bin/bash
# build_scripts/build_all.sh

set -e

echo "=== Dictation Assistant Build Script ==="

echo "[1/4] Getting dependencies..."
flutter pub get

echo "[2/4] Generating code..."
flutter pub run build_runner build --delete-conflicting-outputs

echo "[3/4] Running tests..."
flutter test

PLATFORM=${1:-all}

if [[ "$PLATFORM" == "all" || "$PLATFORM" == "macos" ]]; then
  echo "[4a] Building macOS..."
  flutter build macos --release
fi

if [[ "$PLATFORM" == "all" || "$PLATFORM" == "windows" ]]; then
  echo "[4b] Building Windows..."
  flutter build windows --release
fi

if [[ "$PLATFORM" == "all" || "$PLATFORM" == "android" ]]; then
  echo "[4c] Building Android..."
  flutter build apk --release
fi

echo "=== Build Complete ==="
```

---

## Troubleshooting

### whisper.cpp Model Not Loading

**Symptom**: `TranscriptionException: Model not loaded` or similar

**Solutions**:
1. Verify model file exists at the expected path (check Settings > Models)
2. Ensure the model is in GGML format (not the original PyTorch `.pt` format)
3. Try a smaller model (e.g., `small` or `base`) to rule out memory issues
4. Check that the model file isn't corrupted (re-download if needed)

### No Audio Input

**Symptom**: Recording starts but no transcription appears

**Solutions**:
1. Check microphone permissions in system settings
2. Verify microphone is not muted
3. Check that the correct input device is selected (desktop)
4. Test with another audio recording app to confirm microphone works

### High Latency on Transcription

**Symptom**: Transcription takes >5 seconds per chunk

**Solutions**:
1. Switch to a smaller model (small/base instead of large-v3-turbo)
2. On macOS: Ensure Metal is being used (check logs for backend info)
3. On Windows: Close other CPU-intensive applications
4. Increase chunk duration (modify `AudioConstants.chunkDurationMs`)

### LLM Connection Failed

**Symptom**: "Connection refused" or timeout when testing LLM

**Solutions**:
1. Verify the endpoint URL is correct (include `/v1` if needed)
2. Check API token is valid (if required)
3. For local endpoints (Ollama, LM Studio): Ensure the service is running
4. Check firewall/network settings
5. Review the LLM server logs for detailed error messages

### Arabic Text Display Issues

**Symptom**: Arabic text appears as boxes or wrong direction

**Solutions**:
1. Ensure device has Arabic font support
2. The app handles RTL automatically — verify `languageCode` is set to `'ar'`
3. On desktop: Install Arabic language pack if needed

### Build Errors

**Symptom**: `flutter build` fails with native compilation errors

**Solutions**:
1. Ensure all platform SDKs are installed (Xcode, Visual Studio, Android NDK)
2. Run `flutter clean` then `flutter pub get`
3. Delete `pubspec.lock` and re-run `flutter pub get`
4. For FFI issues: Ensure CMake/NDK versions are compatible

---

## License

MIT License — See [LICENSE](LICENSE) for details.

## Acknowledgments

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) by Georgi Gerganov
- [whisper_ggml_plus](https://pub.dev/packages/whisper_ggml_plus) Flutter FFI bindings
- [Flutter](https://flutter.dev) by Google
- [Drift](https://drift.simonbinder.eu/) by Simon Binder

---

**Version**: 1.0.0 | **Platforms**: Windows, macOS, iOS, Android
