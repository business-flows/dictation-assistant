# ============================================================================
# Dictation Assistant - Makefile
# ============================================================================

.PHONY: help setup clean test build install model models analyze format generate

FLUTTER := flutter
BUILD_RUNNER := dart run build_runner
SCRIPTS := ./build_scripts

# Default target
help: ## Show this help message
	@echo "Dictation Assistant - Available Commands"
	@echo "========================================"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup: ## Install dependencies and generate code
	$(FLUTTER) pub get
	$(BUILD_RUNNER) build --delete-conflicting-outputs

clean: ## Clean build artifacts
	$(FLUTTER) clean
	$(FLUTTER) pub get

update: ## Update dependencies
	$(FLUTTER) pub upgrade

generate: ## Run code generation (freezed, drift, injectable)
	$(BUILD_RUNNER) build --delete-conflicting-outputs

watch: ## Run code generation in watch mode
	$(BUILD_RUNNER) watch --delete-conflicting-outputs

test: ## Run all tests
	$(FLUTTER) test

test-coverage: ## Run tests with coverage
	$(FLUTTER) test --coverage
	genhtml coverage/lcov.info -o coverage/html

analyze: ## Run static analysis
	$(FLUTTER) analyze

format: ## Format all Dart files
	$(FLUTTER) format .

format-check: ## Check formatting
	$(FLUTTER) format --set-exit-if-changed .

# Platform-specific builds
build-macos: ## Build for macOS
	$(SCRIPTS)/build_all.sh macos

build-windows: ## Build for Windows
	$(SCRIPTS)/build_all.sh windows

build-ios: ## Build for iOS
	$(SCRIPTS)/build_all.sh ios

build-android: ## Build for Android (APK + AAB)
	$(SCRIPTS)/build_all.sh android

build-all: ## Build all platforms
	$(SCRIPTS)/build_all.sh all

# Model management
model: ## Download default model (large-v3-turbo)
	$(SCRIPTS)/setup_models.sh large-v3-turbo

models: ## Download all models
	$(SCRIPTS)/setup_models.sh all

model-small: ## Download small model
	$(SCRIPTS)/setup_models.sh small

# Run
dev: ## Run in debug mode (auto-detect device)
	$(FLUTTER) run

dev-macos: ## Run on macOS
	$(FLUTTER) run -d macos

dev-windows: ## Run on Windows
	$(FLUTTER) run -d windows

dev-android: ## Run on Android
	$(FLUTTER) run -d android

dev-ios: ## Run on iOS simulator
	$(FLUTTER) run -d ios

# Utilities
count: ## Count lines of code
	@echo "Dart files:"
	@find lib -name "*.dart" -not -name "*.g.dart" -not -name "*.freezed.dart" | xargs wc -l | tail -1
	@echo "Total .dart files:"
	@find lib -name "*.dart" -not -name "*.g.dart" -not -name "*.freezed.dart" | wc -l
