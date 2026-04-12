@echo off
title --- PUSH CARTE NABIL ---
echo.
echo    [ CARTE NABIL - PUSH et BUILD GitHub Actions ]
echo    Envoi du code vers GitHub...
echo.

cd /d c:\Users\user\Desktop\mimo6\carte-nabil

git add .
git commit -m "Carte Nabil: mise a jour application"
git push -u origin master

echo.
echo ==========================================
echo   Build lance sur GitHub Actions !
echo   Rendez-vous sur GitHub pour telecharger:
echo   - APK Android
echo   - IPA iPhone (non-signe)
echo ==========================================
echo.
pause
