#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

echo "==> CastBridge setup"

if ! command -v pod &>/dev/null; then
  echo "CocoaPods non trovato. Installazione..."
  sudo gem install cocoapods
fi

echo "==> pod install"
pod install

echo ""
echo "Setup completato!"
echo "Apri il progetto con:"
echo "  open CastBridge.xcworkspace"
echo ""
echo "Poi configura il Team di signing in Xcode e compila su iPhone."
