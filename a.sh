#!/bin/bash

clear
echo "=============================================="
echo "     FLUTTER WEB RÁPIDO PARA IPHONE"
echo "=============================================="
echo

echo "Detectando IP local..."
IP=$(ipconfig getifaddr en0)

if [ -z "$IP" ]; then
    IP=$(ipconfig getifaddr en1)
fi

if [ -z "$IP" ]; then
    echo "ERRO: Não foi possível detectar IP Wi-Fi."
    exit 1
fi

echo "IP detectado: $IP"
echo

PORT=8080
URL="http://$IP:$PORT"

echo "Servidor rodará em: $URL"
echo

echo "=============================================="
echo "     GERANDO QR CODE PARA O iPHONE"
echo "=============================================="
echo

QR="https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=$URL"
echo "$QR"
echo
echo "Abra o link acima para ver o QR Code."
echo

echo "=============================================="
echo "       BUILD WEB OTIMIZADA (RELEASE)"
echo "=============================================="
echo

flutter build web --release --no-wasm-dry-run

echo
echo "Build concluída!"
echo

echo "=============================================="
echo "   INICIANDO SERVIDOR EFICIENTE PARA IPHONE"
echo "=============================================="
echo

# Subir servidor com flutter sem debug pesado
flutter run -d web-server --release --web-hostname 0.0.0.0 --web-port $PORT

echo
echo "Servidor encerrado."
#./a.sh
#flutter clean
#flutter pub get
#flutter run -d chrome