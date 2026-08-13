@echo off

REM Change if needed
set RPATH="C:\Program Files\R\R-3.5.2\bin\"

set oldpath=%path%

set platform=ia32
if "%1"=="64" set platform=intel64

set r=%RPATH%i386\R.exe
if "%1"=="64" set r=%RPATH%x64\R.exe

set driver=TutorialDriver
if "%1"=="sample" set driver=sample
if "%2"=="sample" set driver=sample

set path=%BARRA_OPS_HOME%bin\%platform%
set BARRAOPT_WRAP=%BARRA_OPS_HOME%bin\%platform%\barraopt_wrap.dll
set BARRAOPT_WRAP_R=%BARRA_OPS_HOME%bin\barraopt_wrap.R

%r% CMD BATCH -q --vanilla "--args %*" %driver%.r

set path=%oldpath%

type %driver%.r.rout

