#!/bin/bash
echo "Baixando o Flutter SDK..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1

echo "Configurando variáveis de ambiente..."
export PATH="$PATH:`pwd`/flutter/bin"

echo "Instalando dependências..."
flutter pub get

echo "Compilando para Web..."
flutter build web --release
