#!/bin/bash
set -euo pipefail

echo "=== BPM Bank - Build para Vercel ==="
echo "PWD: $(pwd)"
echo "VERCEL_CACHE_DIR: ${VERCEL_CACHE_DIR:-<undefined>}"

FLUTTER_VERSION="3.24.3"
FLUTTER_CHANNEL="stable"
CACHE_DIR="${VERCEL_CACHE_DIR:-$(pwd)/.vercel_cache}"
FLUTTER_DIR="$CACHE_DIR/flutter"
FLUTTER_STORAGE_URL="https://storage.googleapis.com/flutter_infra_release/releases"

mkdir -p "$CACHE_DIR"

echo ""
echo "=== Verificando cache do Flutter ==="
if [ -d "$FLUTTER_DIR/bin" ] && [ -x "$FLUTTER_DIR/bin/flutter" ]; then
  INSTALLED_VERSION=$("$FLUTTER_DIR/bin/flutter" --version --machine | grep '"frameworkVersion"' | sed 's/.*"frameworkVersion": "\(.*\)".*/\1/')
  echo "Flutter já instalado (cache): $INSTALLED_VERSION"
  if [ "$INSTALLED_VERSION" != "$FLUTTER_VERSION" ]; then
    echo "Versão desatualizada. Re-instalando..."
    rm -rf "$FLUTTER_DIR"
  fi
fi

if [ ! -d "$FLUTTER_DIR/bin" ] || [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "Baixando Flutter SDK $FLUTTER_VERSION ($FLUTTER_CHANNEL)..."
  OS="linux"
  ARCH="x64"
  FLUTTER_ARTIFACT="flutter_${OS}_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz"
  DOWNLOAD_URL="${FLUTTER_STORAGE_URL}/${FLUTTER_CHANNEL}/${OS}/${FLUTTER_ARTIFACT}"

  echo "Download URL: $DOWNLOAD_URL"
  curl -fSL --retry 3 --retry-delay 2 "$DOWNLOAD_URL" -o "$CACHE_DIR/flutter.tar.xz"

  echo "Extraindo..."
  mkdir -p "$FLUTTER_DIR"
  tar -xf "$CACHE_DIR/flutter.tar.xz" -C "$FLUTTER_DIR" --strip-components=1
  rm -f "$CACHE_DIR/flutter.tar.xz"

  echo "Instalando..."
else
  echo "Usando Flutter do cache!"
fi

echo "=== Configurando PATH ==="
export PATH="$FLUTTER_DIR/bin:$FLUTTER_DIR/bin/cache/dart-sdk/bin:$PATH"
export PUB_CACHE="$CACHE_DIR/pub-cache"
mkdir -p "$PUB_CACHE"

echo "Flutter version:"
flutter --version

echo ""
echo "=== Instalando dependências (flutter pub get) ==="
cd "$(dirname "$0")"
flutter pub get

echo ""
echo "=== Gerando arquivo .env ==="
ENV_FILE="$(dirname "$0")/.env"
{
  echo "GROQ_API_KEY=${GROQ_API_KEY:-placeholder}"
  echo "SUPABASE_URL=${SUPABASE_URL:-placeholder}"
  echo "SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-placeholder}"
  echo "SUPABASE_PASSWORD=${SUPABASE_PASSWORD:-placeholder}"
} > "$ENV_FILE"
echo ".env criado com sucesso em $ENV_FILE"

echo ""
echo "=== Compilando para Web ==="
flutter build web --release --dart-define-from-file=.env --no-tree-shake-icons

echo ""
echo "=== Build finalizado! ==="
echo "Output: $(pwd)/build/web"
ls -la build/web/
