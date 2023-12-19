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
call %vcdir%\vcvarsall.bat %target%
set path=%BARRA_OPS_HOME%bin\%opsplatform%;%path%

set p=x86
if "%1"=="64" set p=x64

copy "%BARRA_OPS_HOME%bin\opsproto_cs.dll"
copy "%BARRA_OPS_HOME%bin\Google.ProtocolBuffers.dll"

csc.exe /platform:%p% /reference:opsproto_cs.dll /reference:Google.ProtocolBuffers.dll /out:tutorial.exe *.cs

tutorial

goto end

:novc

echo You may need change the vcdir variable in runtutorial.bat

:end

set path=%oldpath%
