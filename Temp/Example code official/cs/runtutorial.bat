@echo off
REM This batch is to be used to compile/run C# tutorials

rem vs 2017
set vcdir="C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\VC\Auxiliary\Build"
rem vs 2012
rem set vcdir="C:\Program Files (x86)\Microsoft Visual Studio 11.0\VC"
if not exist %vcdir% goto novc

set oldpath=%path%

set target=x86
if "%1"=="64" set target=amd64
set opsplatform=ia32
if "%1"=="64" set opsplatform=intel64
call %vcdir%\vcvarsall.bat %target% > nul
set path=%BARRA_OPS_HOME%bin\%opsplatform%;%path%

set p=x86
if "%1"=="64" set p=x64

IF not exist barraopt_cs.dll mklink barraopt_cs.dll "%BARRA_OPS_HOME%bin\barraopt_cs.dll" > nul

set buildtarget=Tutorial
if "%1"=="sample" set buildtarget=sample
if "%2"=="sample" set buildtarget=sample

csc.exe /nologo /platform:%p% /reference:"%BARRA_OPS_HOME%bin\barraopt_cs.dll" /out:"%buildtarget%.exe" "%buildtarget%*.cs"

%buildtarget% %*

goto end

:novc

echo You need to change the vcdir variable in runtutorial.bat

:end

set path=%oldpath%
