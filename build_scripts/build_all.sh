#!/bin/bash
# ============================================================================
# Dictation Assistant - Build Script
# ============================================================================
# Usage: ./build_all.sh [platform]
#   platform: all (default) | macos | windows | ios | android | linux
#
# Examples:
#   ./build_all.sh              # Build all supported platforms
#   ./build_all.sh macos        # Build macOS only
#   ./build_all.sh windows      # Build Windows only
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build_outputs"
PLATFORM="${1:-all}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

header() {
    echo ""
    echo "============================================================"
    echo "  $1"
    echo "============================================================"
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

check_flutter() {
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter SDK not found. Install from https://flutter.dev"
        exit 1
    fi

    FLUTTER_VERSION=$(flutter --version | head -1 | awk '{print $2}')
    log_info "Flutter version: $FLUTTER_VERSION"
}

check_deps() {
    header "Checking Dependencies"
    cd "$PROJECT_ROOT"

    log_info "Running flutter pub get..."
    flutter pub get

    log_info "Running build_runner..."
    if ! dart run build_runner build --delete-conflicting-outputs; then
        log_warn "Build runner had issues, trying again..."
        dart run build_runner build --delete-conflicting-outputs
    fi

    log_success "Dependencies ready"
}

run_tests() {
    header "Running Tests"
    cd "$PROJECT_ROOT"

    if flutter test; then
        log_success "All tests passed"
    else
        log_warn "Some tests failed — continuing with build"
    fi
}

# ============================================================================
# Platform Builds
# ============================================================================

build_macos() {
    header "Building macOS"
    cd "$PROJECT_ROOT"

    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_warn "macOS builds require macOS host. Skipping."
        return 0
    fi

    flutter build macos --release

    APP_PATH="build/macos/Build/Products/Release/Dictation Assistant.app"
    if [ -d "$APP_PATH" ]; then
        mkdir -p "$BUILD_DIR/macos"
        cp -R "$APP_PATH" "$BUILD_DIR/macos/"
        log_success "macOS build: $BUILD_DIR/macos/Dictation Assistant.app"
    fi
}

build_windows() {
    header "Building Windows"
    cd "$PROJECT_ROOT"

    if [[ "$OSTYPE" == "darwin"* || "$OSTYPE" == "linux"* ]]; then
        log_warn "Cross-compiling Windows from non-Windows host not supported."
        log_info "To build on Windows, run: flutter build windows --release"
        return 0
    fi

    flutter build windows --release

    EXE_DIR="build/windows/x64/runner/Release"
    if [ -d "$EXE_DIR" ]; then
        mkdir -p "$BUILD_DIR/windows"
        cp -R "$EXE_DIR"/* "$BUILD_DIR/windows/"
        log_success "Windows build: $BUILD_DIR/windows/"
    fi
}

build_ios() {
    header "Building iOS"
    cd "$PROJECT_ROOT"

    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_warn "iOS builds require macOS host. Skipping."
        return 0
    fi

    flutter build ios --release --no-codesign

    APP_PATH="build/ios/iphoneos/Runner.app"
    if [ -d "$APP_PATH" ]; then
        mkdir -p "$BUILD_DIR/ios"
        cp -R "$APP_PATH" "$BUILD_DIR/ios/"
        log_success "iOS build: $BUILD_DIR/ios/Runner.app"
    fi
}

build_android() {
    header "Building Android"
    cd "$PROJECT_ROOT"

    flutter build apk --release

    APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
    if [ -f "$APK_PATH" ]; then
        mkdir -p "$BUILD_DIR/android"
        cp "$APK_PATH" "$BUILD_DIR/android/dictation-assistant.apk"
        log_success "Android APK: $BUILD_DIR/android/dictation-assistant.apk"
    fi

    # Also build AAB for Play Store
    log_info "Building Android App Bundle..."
    flutter build appbundle --release

    AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
    if [ -f "$AAB_PATH" ]; then
        cp "$AAB_PATH" "$BUILD_DIR/android/dictation-assistant.aab"
        log_success "Android AAB: $BUILD_DIR/android/dictation-assistant.aab"
    fi
}

build_linux() {
    header "Building Linux"
    cd "$PROJECT_ROOT"

    if [[ "$OSTYPE" != "linux"* ]]; then
        log_warn "Linux builds require Linux host. Skipping."
        return 0
    fi

    flutter build linux --release

    BIN_DIR="build/linux/x64/release/bundle"
    if [ -d "$BIN_DIR" ]; then
        mkdir -p "$BUILD_DIR/linux"
        cp -R "$BIN_DIR"/* "$BUILD_DIR/linux/"
        log_success "Linux build: $BUILD_DIR/linux/"
    fi
}

# ============================================================================
# Main
# ============================================================================

main() {
    header "Dictation Assistant Build"
    log_info "Platform: $PLATFORM"
    log_info "Output: $BUILD_DIR"

    check_flutter
    check_deps
    run_tests

    mkdir -p "$BUILD_DIR"

    case "$PLATFORM" in
        all)
            build_macos
            build_windows
            build_ios
            build_android
            build_linux
            ;;
        macos)
            build_macos
            ;;
        windows)
            build_windows
            ;;
        ios)
            build_ios
            ;;
        android)
            build_android
            ;;
        linux)
            build_linux
            ;;
        *)
            log_error "Unknown platform: $PLATFORM"
            echo "Usage: $0 [all|macos|windows|ios|android|linux]"
            exit 1
            ;;
    esac

    header "Build Complete"
    log_info "Outputs in: $BUILD_DIR"
    
    if [ -d "$BUILD_DIR" ]; then
        echo ""
        find "$BUILD_DIR" -type f | while read -r f; do
            SIZE=$(du -h "$f" | cut -f1)
            echo "  $SIZE  $f"
        done
    fi
}

main "$@"
