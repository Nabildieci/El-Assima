@echo off
echo.
echo  [42m [ ASSIMA-10 : FORCE BUILD GITHUB ] [0m
echo.

:: Add and commit even if empty
git add .
git commit --allow-empty -m "Force Build Trigger: %date% %time%"

:: Force push to both main and master
echo.
echo [*] Envoi force vers GitHub...
git push origin master:master --force
git push origin master:main --force

echo.
echo [OK] Push effectue ! Verifiez vos actions ici :
echo https://github.com/djenadimohamedamine-code/carte-nabil/actions
echo.
pause
