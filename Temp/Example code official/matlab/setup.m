% The following function will set up the Java classpath and librarypath for Open Optimizer
% Specifically, it will append the Open Optimizer JAR file path to javaclasspath.txt under `prefdir`
% and append the Open Optimizer executable path to javalibrarypath.txt under `userpath`
% function input argument is "32" for using 32-bit Optimizer and "64" for using 64-bit Optimizer
function [] = setup(arg1)
up = userpath
up = regexprep(up, ';', '')
javaclasspathtxt = strcat(up ,'\javaclasspath.txt')
jarfilepath = strrep(strcat(getenv('BARRA_OPS_HOME'), 'bin\OptJAVAAPI.jar'), '\', '/')
fid = fopen(javaclasspathtxt, 'a+')
fprintf(fid, '\n')
fprintf(fid, jarfilepath)
fprintf(fid, '\n')
fclose(fid)
fprintf('Open Optimizer JAR file path %s was successfully added to %s', jarfilepath, javaclasspathtxt)

javalibrarypathtxt = strcat(up, '\javalibrarypath.txt')
if strcmp(arg1, '64')
	librarypath = strcat(getenv('BARRA_OPS_HOME'), 'bin\intel64')
else
	librarypath = strcat(getenv('BARRA_OPS_HOME'), 'bin\ia32')
end

librarypath2 = strrep(librarypath, '\', '/')
fid = fopen(javalibrarypathtxt, 'a+')
fprintf(fid, '\n')
fprintf(fid, librarypath2)
fprintf(fid, '\n')
fclose(fid)
fprintf('Open Optimizer library path %s was successfully added to %s', librarypath2, javalibrarypathtxt)

exit
end
