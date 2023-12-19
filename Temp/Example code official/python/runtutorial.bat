@echo off

REM Python version must match the one selected at Barra OPtimizer installation

if "%1"=="64" (
	set platform=intel64
) else (
	set platform=ia32
)

set PYTHONPATH=%BARRA_OPS_HOME%bin\%platform%;%BARRA_OPS_HOME%bin

set driver=TutorialDriver
if "%1"=="sample" set driver=sample
if "%2"=="sample" set driver=sample

python.exe %driver%.py %*