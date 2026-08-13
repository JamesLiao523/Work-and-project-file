@echo off
REM This batch is to be used to compile/run C++ tutorials with MS Visual Studio 2017
REM To compile C++ tutorials with earlier versions of MS Visual Studio, you will need to change the platform toolset in project setting.

rem vs 2017
set vcdir="C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\VC\Auxiliary\Build"
rem vs 2012
rem set vcdir="C:\Program Files (x86)\Microsoft Visual Studio 11.0\VC"

if not exist %vcdir% goto novc

set oldpath=%path%

set target=x86
if "%1"=="64" set target=amd64

set arch=ia32
if "%1"=="64" set arch=intel64

set path=%BARRA_OPS_HOME%bin\%arch%;%path%

call %vcdir%\vcvarsall.bat %target% 

set buildtarget=Tutorial
if "%1"=="sample" set buildtarget=sample
if "%2"=="sample" set buildtarget=sample

REM build the tutorials
cl /nologo /EHsc /MD -I "%BARRA_OPS_HOME%include" "%buildtarget%*.cpp" /link "%BARRA_OPS_HOME%lib\%arch%\barraopt.lib" /out:"%buildtarget%.exe" 

REM run tutorials
%buildtarget% %*

goto end

:novc

echo You need to change the vcdir variable in runtutorial.bat

:end

set path=%oldpath%