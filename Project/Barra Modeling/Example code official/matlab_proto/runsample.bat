@echo off

REM 32-bit matlab; Change if needed
set MATLAB32="c:\Program Files (x86)\MATLAB\R2009b\"

REM 64-bit matlab; Change if needed
set MATLAB64="c:\Program Files\MATLAB\R2015b\"

set oldpath=%path%

if "%1"=="64" goto else64
	set MATLAB=%MATLAB32%\bin\matlab
	copy /y librarypath.txt.32 javalibrarypath.txt
	goto endif
:else64
	set path=%BARRA_OPS_HOME%bin\intel64
	set MATLAB=%MATLAB64%\bin\win64\matlab
	copy /y librarypath.txt.64 javalibrarypath.txt
:endif

%MATLAB% -nosplash -nodesktop -logfile sample.out -r "sample; quit"

set path=%oldpath%