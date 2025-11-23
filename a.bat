@echo off
title Nuryon - Servidor Flutter para iPhone

echo ==============================================
echo     NURYON - FLUTTER WEB PARA IPHONE
echo ==============================================
echo.

echo Detectando IP local...

for /f "tokens=2 delims=:" %%A in ('ipconfig ^| findstr /i "IPv4 Address"') do set IP=%%A
set IP=%IP: =%

echo IP detectado: %IP%
echo.
set PORT=8080
echo Servidor rodara em: http://%IP%:%PORT%
echo.

echo Verificando Flutter...
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERRO: Flutter nao foi encontrado no PATH!
    pause
    exit /b
)

echo Flutter encontrado!
echo.

echo ==============================================
echo GERANDO QR CODE PARA ACESSO NO IPHONE
echo ==============================================

set "URL=http://%IP%:%PORT%"
set "QR=https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=%URL%"

echo Abra este link para ver o QR Code:
echo %QR%
echo.
echo Use a camera do iPhone para abrir o link.
echo.

echo Iniciando servidor Flutter...
echo (Pressione CTRL + C para parar)
echo.

flutter run -d web-server --web-hostname 0.0.0.0 --web-port %PORT%

echo.
echo Servidor encerrado.
pause
