@echo off
REM =====================================================================
REM Executa o workflow carga_completa (RF22) - uso manual ou agendado
REM Log de cada execucao: logs\carga_completa_AAAAMMDD_HHMMSS.log
REM Codigo de saida: 0 = sucesso, diferente de 0 = falha
REM =====================================================================
setlocal

REM Pasta do projeto = pasta acima deste script
cd /d "%~dp0.."
set PROJ=%CD%

if not exist "%PROJ%\logs" mkdir "%PROJ%\logs"

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set DATAHORA=%%i
set LOG=%PROJ%\logs\carga_completa_%DATAHORA%.log

cmd /c C:\hop\hop-run.bat -j desafio_dados_2 -e dev -f "%PROJ%\hop\workflows\carga_completa.hwf" -r local -l Basic > "%LOG%" 2>&1
set RESULTADO=%ERRORLEVEL%

echo Codigo de saida: %RESULTADO% >> "%LOG%"
exit /b %RESULTADO%
