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
echo "=== Configurando git para evitar dubious ownership ==="
export GIT_CONFIG_GLOBAL="$CACHE_DIR/.gitconfig"
{
  echo "[safe]"
  echo "    directory = *"
} > "$GIT_CONFIG_GLOBAL"
echo "Git safe.directory=* configurado."

echo ""
echo "=== Verificando cache do Flutter ==="
NEEDS_INSTALL=0
if [ -d "$FLUTTER_DIR/bin" ] && [ -x "$FLUTTER_DIR/bin/flutter" ]; then
  if [ -f "$FLUTTER_DIR/version" ]; then
    INSTALLED_VERSION=$(cat "$FLUTTER_DIR/version" | tr -d '[:space:]')
  else
    INSTALLED_VERSION="unknown"
  fi
  echo "Flutter já instalado (cache): $INSTALLED_VERSION"
  if [ "$INSTALLED_VERSION" != "$FLUTTER_VERSION" ]; then
    echo "Versão desatualizada. Re-instalando..."
    rm -rf "$FLUTTER_DIR"
    NEEDS_INSTALL=1
  fi
else
  NEEDS_INSTALL=1
fi

if [ "$NEEDS_INSTALL" -eq 1 ]; then
  echo "Baixando Flutter SDK $FLUTTER_VERSION ($FLUTTER_CHANNEL)..."
  OS="linux"
  FLUTTER_ARTIFACT="flutter_${OS}_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz"
  DOWNLOAD_URL="${FLUTTER_STORAGE_URL}/${FLUTTER_CHANNEL}/${OS}/${FLUTTER_ARTIFACT}"

  echo "Download URL: $DOWNLOAD_URL"
  curl -fSL --retry 3 --retry-delay 2 "$DOWNLOAD_URL" -o "$CACHE_DIR/flutter.tar.xz"

  echo "Extraindo..."
  TMP_EXTRACT="$CACHE_DIR/flutter-tmp"
  rm -rf "$TMP_EXTRACT"
  mkdir -p "$TMP_EXTRACT"
  tar -xf "$CACHE_DIR/flutter.tar.xz" -C "$TMP_EXTRACT" --no-same-owner
  rm -f "$CACHE_DIR/flutter.tar.xz"

  echo "Ajustando ownership e removendo .git do SDK..."
  mv "$TMP_EXTRACT/flutter" "$FLUTTER_DIR"
  rm -rf "$TMP_EXTRACT"
  rm -rf "$FLUTTER_DIR/.git"

  echo "Flutter $FLUTTER_VERSION instalado!"
else
  echo "Usando Flutter do cache!"
fi

echo "=== Configurando PATH e variáveis do Flutter ==="
export PATH="$FLUTTER_DIR/bin:$FLUTTER_DIR/bin/cache/dart-sdk/bin:$PATH"
export PUB_CACHE="$CACHE_DIR/pub-cache"
export FLUTTER_ROOT="$FLUTTER_DIR"
mkdir -p "$PUB_CACHE"

echo "Desativando analytics e animações do Flutter CLI..."
"$FLUTTER_DIR/bin/flutter" config --no-analytics --no-cli-animations 2>/dev/null || true

echo "Flutter version:"
"$FLUTTER_DIR/bin/flutter" --version --machine | head -c 200 ; echo ""

echo ""
echo "=== Instalando dependências (flutter pub get) ==="
cd "$(dirname "$0")"
"$FLUTTER_DIR/bin/flutter" pub get

echo ""
echo "=== Gerando arquivo .env ==="
ENV_FILE="$(dirname "$0")/.env"
{
  echo "GROQ_API_KEY=${GROQ_API_KEY:-placeholder}"
  echo "SUPABASE_URL=${SUPABASE_URL:-placeholder}"
  echo "SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-placeholder}"
  echo "SUPABASE_PASSWORD=${SUPABASE_PASSWORD:-placeholder}"
} > "$ENV_FILE"
echo ".env criado com sucesso."

echo ""
echo "=== Compilando para Web ==="
"$FLUTTER_DIR/bin/flutter" build web --release --dart-define-from-file=.env --no-tree-shake-icons

echo ""
echo "=== Build finalizado! ==="
echo "Output: $(pwd)/build/web"
ls -la build/web/
