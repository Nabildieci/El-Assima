#!/bin/bash
# Script de build personnalisé pour Vercel (installation de Flutter incluse)

echo "📥 Installation de Flutter SDK..."
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable flutter
fi

export PATH="$PATH:`pwd`/flutter/bin"

echo "⚙️ Configuration de Flutter Web..."
flutter config --enable-web

echo "📦 Téléchargement des dépendances..."
flutter pub get

echo "🏗️ Compilation de l'application Web..."
flutter build web --release --web-renderer canvaskit

echo "📁 Préparation du dossier de sortie Vercel..."
rm -rf public
mv build/web public

echo "✅ Compilation terminée."
