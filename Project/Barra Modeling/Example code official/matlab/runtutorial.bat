@echo off

set oldpath=%path%

if "%1"=="64" goto else64
	set path=%BARRA_OPS_HOME%bin\ia32;%path%
	copy /y librarypath.txt.32 javalibrarypath.txt
	set driver=TutorialDriver
	if "%1"=="sample" set driver=sample
	if "%2"=="sample" set driver=sample	
	goto endif
:else64
	set path=%BARRA_OPS_HOME%bin\intel64;%path%
	copy /y librarypath.txt.64 javalibrarypath.txt
	if "%2"=="sample" (
		set driver=sample 
	) else (
		set driver=TutorialDriver
	)
:endif

if "%ML_LOG_FILE%"=="" set ML_LOG_FILE=runtutorial.out

matlab -nosplash -nodesktop -wait -logfile %ML_LOG_FILE% -r "argline='%*'; %driver%; quit"
goto end

:end

set path=%oldpath%