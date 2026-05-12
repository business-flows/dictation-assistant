#!/bin/bash
# ============================================================================
# Dictation Assistant - Model Download Script
# ============================================================================
# Downloads whisper.cpp GGML models from Hugging Face.
#
# Usage: ./setup_models.sh [model_id] [output_dir]
#   model_id:  large-v3-turbo | large-v3 | small | base | tiny | all
#   output_dir: Directory to save models (default: ./assets/models)
#
# Examples:
#   ./setup_models.sh large-v3-turbo           # Download default model
#   ./setup_models.sh all ~/Documents/models   # Download all models
#   ./setup_models.sh small base               # Download multiple
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_OUTPUT="$SCRIPT_DIR/../assets/models"
OUTPUT_DIR="${2:-$DEFAULT_OUTPUT}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

BASE_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

# Model registry
declare -A MODELS
MODELS[large-v3-turbo]="ggml-large-v3-turbo.bin"
MODELS[large-v3]="ggml-large-v3.bin"
MODELS[small]="ggml-small.bin"
MODELS[base]="ggml-base.bin"
MODELS[tiny]="ggml-tiny.bin"

# Model sizes (approximate, for user info)
declare -A MODEL_SIZES
MODEL_SIZES[large-v3-turbo]="~1.6 GB"
MODEL_SIZES[large-v3]="~3.1 GB"
MODEL_SIZES[small]="~466 MB"
MODEL_SIZES[base]="~148 MB"
MODEL_SIZES[tiny]="~78 MB"

# ============================================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

download_model() {
    local model_id="$1"
    local filename="${MODELS[$model_id]}"
    local url="$BASE_URL/$filename"
    local output_path="$OUTPUT_DIR/$filename"

    if [ -z "$filename" ]; then
        log_error "Unknown model: $model_id"
        return 1
    fi

    if [ -f "$output_path" ]; then
        log_warn "Model already exists: $filename"
        read -p "Re-download? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping $model_id"
            return 0
        fi
    fi

    log_info "Downloading $model_id (${MODEL_SIZES[$model_id]})..."
    log_info "URL: $url"
    log_info "Output: $output_path"
    echo ""

    mkdir -p "$OUTPUT_DIR"

    if command -v curl &> /dev/null; then
        curl -L --progress-bar -o "$output_path" "$url"
    elif command -v wget &> /dev/null; then
        wget --progress=bar:force -O "$output_path" "$url"
    else
        log_error "curl or wget required"
        exit 1
    fi

    # Verify file was downloaded
    if [ -f "$output_path" ] && [ -s "$output_path" ]; then
        local size=$(du -h "$output_path" | cut -f1)
        log_success "Downloaded: $filename ($size)"
    else
        log_error "Download failed for $model_id"
        return 1
    fi
}

show_help() {
    echo "Dictation Assistant - Model Download Script"
    echo ""
    echo "Usage: $0 [model_id|all] [output_dir]"
    echo ""
    echo "Available models:"
    for id in "${!MODELS[@]}"; do
        printf "  %-18s %s\n" "$id" "${MODEL_SIZES[$id]}"
    done
    echo ""
    echo "Examples:"
    echo "  $0 large-v3-turbo              # Download default model"
    echo "  $0 all                         # Download all models"
    echo "  $0 small base                  # Download multiple models"
    echo "  $0 large-v3-turbo ~/models     # Custom output directory"
}

# ============================================================================

main() {
    if [ $# -eq 0 ] || [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
        show_help
        exit 0
    fi

    # Check if output dir was specified as last argument
    if [ -d "${!#}" ]; then
        OUTPUT_DIR="${!#}"
        set -- "${@:1:$#-1}"
    fi

    log_info "Output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"

    if [ "$1" == "all" ]; then
        log_info "Downloading all models..."
        for model_id in "${!MODELS[@]}"; do
            download_model "$model_id" || true
            echo ""
        done
    else
        for model_id in "$@"; do
            if [ -d "$model_id" ]; then continue; fi
            download_model "$model_id" || true
            echo ""
        done
    fi

    echo ""
    log_success "Done! Models in: $OUTPUT_DIR"
    ls -lh "$OUTPUT_DIR"
}

main "$@"
