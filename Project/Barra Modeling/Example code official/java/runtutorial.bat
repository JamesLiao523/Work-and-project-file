@echo off

set oldpath=%path%

Rem JDK paths; change if needed
if "%JAVA32%"=="" set JAVA32=C:\Program Files (x86)\Java\jdk1.8.0_202\
if "%JAVA64%"=="" set JAVA64=C:\Program Files\Java\jdk-11.0.2\

if "%1"=="64" (
	if not exist "%JAVA64%" goto nojdk
) else (
	if not exist "%JAVA32%" goto nojdk
)

set path=%BARRA_OPS_HOME%bin\ia32;%JAVA32%bin
if "%1"=="64" set path=%BARRA_OPS_HOME%bin\intel64;%JAVA64%bin

set build=Tutorial
if "%1"=="sample" set build=sample
if "%2"=="sample" set build=sample
if "%build%"=="Tutorial" (
	set driver=TutorialDriver
) else (
	set driver=sample
)

javac -classpath "%BARRA_OPS_HOME%bin\OptJAVAAPI.jar" %build%*.java
java  -classpath "%BARRA_OPS_HOME%bin\OptJAVAAPI.jar;." %driver% %*

goto end

:nojdk

echo you may need to change the JAVA32 and/or JAVA64 variable(s) in runtutorial.bat/environment

:end

set path=%oldpath%


