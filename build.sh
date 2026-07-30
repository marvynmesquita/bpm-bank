#!/bin/bash
echo "Baixando o Flutter SDK..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1

echo "Configurando variáveis de ambiente..."
export PATH="$PATH:`pwd`/flutter/bin"

echo "Instalando dependências..."
flutter pub get

echo "Gerando arquivo .env a partir das variáveis do Vercel..."
echo "GEMINI_API_KEY=\"$GEMINI_API_KEY\"" > .env
echo "SUPABASE_URL=\"$SUPABASE_URL\"" >> .env
echo "SUPABASE_ANON_KEY=\"$SUPABASE_ANON_KEY\"" >> .env
echo "SUPABASE_PASSWORD=\"$SUPABASE_PASSWORD\"" >> .env

echo "Compilando para Web..."
flutter build web --release
