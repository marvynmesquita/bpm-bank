#!/bin/bash
set -euo pipefail

echo "=== BPM Bank - Build para Vercel ==="
echo "PWD: $(pwd)"
echo "VERCEL_CACHE_DIR: ${VERCEL_CACHE_DIR:-<undefined>}"

FLUTTER_VERSION="3.24.3"
FLUTTER_CHANNEL="stable"
CACHE_DIR="${VERCEL_CACHE_DIR:-$(pwd)/.vercel_cache}"
FLUTTER_DIR="$CACHE_DIR/flutter-sdk"
FLUTTER_STORAGE="https://storage.googleapis.com/flutter_infra_release/releases"

export HOME="$CACHE_DIR/home"
export PUB_CACHE="$CACHE_DIR/pub-cache"
export FLUTTER_ROOT="$FLUTTER_DIR"
mkdir -p "$HOME" "$CACHE_DIR" "$PUB_CACHE" "$FLUTTER_DIR"

GITCONFIG_DIR="$HOME/.config/git"
mkdir -p "$GITCONFIG_DIR"
cat > "$GITCONFIG_DIR/config" <<EOF
[safe]
    directory = *
[init]
    defaultBranch = main
[user]
    email = build@vercel.local
    name = Vercel Build
EOF
export GIT_CONFIG_GLOBAL="$GITCONFIG_DIR/config"
export GIT_CONFIG_NOSYSTEM=1
echo "Git: safe.directory=* ativo."

echo ""
echo "=== Cache check Flutter SDK ==="
INSTALLED_OK=0
if [ -x "$FLUTTER_DIR/bin/flutter" ] && [ -f "$FLUTTER_DIR/version" ]; then
  V=$(tr -d '[:space:]' < "$FLUTTER_DIR/version")
  if [ "$V" = "$FLUTTER_VERSION" ]; then
    INSTALLED_OK=1
    echo "Cache HIT: Flutter $V"
  fi
fi

if [ "$INSTALLED_OK" -ne 1 ]; then
  echo "Instalando Flutter SDK $FLUTTER_VERSION ($FLUTTER_CHANNEL)..."
  ARTIFACT="flutter_linux_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz"
  DOWNLOAD_URL="${FLUTTER_STORAGE}/${FLUTTER_CHANNEL}/linux/${ARTIFACT}"
  echo "Baixando: $DOWNLOAD_URL"
  curl -fSL --retry 3 --retry-delay 2 "$DOWNLOAD_URL" -o "$CACHE_DIR/flutter.tar.xz"

  echo "Extraindo..."
  EXTRACT_DIR="$CACHE_DIR/_extract"
  rm -rf "$EXTRACT_DIR" "$FLUTTER_DIR"
  mkdir -p "$EXTRACT_DIR" "$FLUTTER_DIR"
  tar -xf "$CACHE_DIR/flutter.tar.xz" -C "$EXTRACT_DIR" --no-same-owner --no-same-permissions
  rm -f "$CACHE_DIR/flutter.tar.xz"

  SRC_FLUTTER="$EXTRACT_DIR/flutter"
  if [ -d "$SRC_FLUTTER" ]; then
    cp -a "$SRC_FLUTTER/." "$FLUTTER_DIR/"
  fi
  rm -rf "$EXTRACT_DIR"
  chmod -R u+rwX "$FLUTTER_DIR" 2>/dev/null || true

  echo "Garantindo .git do SDK (Flutter CLI requer)..."
  if [ -d "$FLUTTER_DIR/.git" ]; then
    echo "  -> .git existia no tarball"
    ( cd "$FLUTTER_DIR" && git config --local safe.directory "$FLUTTER_DIR" 2>/dev/null || true )
  else
    echo "  -> .git nao veio no tarball - inicializando minimo"
    (
      cd "$FLUTTER_DIR"
      git init -q -b main
      git add -A >/dev/null 2>&1 || true
      git -c commit.gpgsign=false commit -q --allow-empty -m "flutter-sdk-snapshot" >/dev/null 2>&1 || true
    )
  fi
  echo "SDK instalado com sucesso."
fi

export PATH="$FLUTTER_DIR/bin:$FLUTTER_DIR/bin/cache/dart-sdk/bin:$PATH"

echo ""
echo "=== Configuracao final Flutter ==="
git config --global --add safe.directory "$FLUTTER_DIR" 2>/dev/null || true
git config --global --add safe.directory "$(pwd)" 2>/dev/null || true

"$FLUTTER_DIR/bin/flutter" config --no-analytics --no-cli-animations --enable-web 2>/dev/null || true

echo "flutter --version:"
"$FLUTTER_DIR/bin/flutter" --version

echo ""
echo "=== flutter pub get ==="
cd "$(dirname "$0")"
"$FLUTTER_DIR/bin/flutter" pub get

echo ""
echo "=== Gerando .env ==="
{
  echo "GROQ_API_KEY=${GROQ_API_KEY:-placeholder}"
  echo "SUPABASE_URL=${SUPABASE_URL:-placeholder}"
  echo "SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-placeholder}"
  echo "SUPABASE_PASSWORD=${SUPABASE_PASSWORD:-placeholder}"
} > .env
echo ".env OK"

echo ""
echo "=== flutter build web ==="
"$FLUTTER_DIR/bin/flutter" build web --release --dart-define-from-file=.env --no-tree-shake-icons

echo ""
echo "=== Build concluido! ==="
ls -la build/web/
