@echo off
REM 
REM Usage: runtutorial.bat <32 or 64-bit>
REM
REM For example, to run tutorials in 32-bit:
REM runtutorial.bat 32
REM

set oldpath=%path%

set platform=ia32
if "%1"=="64" set platform=intel64

set path=%BARRA_OPS_HOME%bin\%platform%;%path%

for /f "delims=." %%a in ('dir /b Case*.xml') do openopt.exe -run -ws %%a.xml -o Result_%%a.xml

set path=%oldpath%
