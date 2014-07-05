 @echo off

::******************************************************************************
::-- Variables/Constants
::******************************************************************************

set ROBOJOB_EXT=.rcj
set TEMP_JOB_FILEPATH=%TEMP%\robobackup%ROBOJOB_EXT%
set LOG_PATH_PREFIX=%TEMP%\robojob

set PASSIVE_MODE=false 
set PASSIVE_REFRESH_PERIOD=30 
set PREVIEW_MODE=false 

::******************************************************************************
::-- Main Entry
::******************************************************************************

::------------------------------------------------------------------------------
:: Command Options:
::
::     /PASSIVE, /P  Turn monitoring on with the robocopy commands
::     /PREVIEW, /L  
:main
	:parseCmdOptions
	set paramStr=%1
	set switchFlag=%paramStr:~0,1%
	set switchName=%paramStr:~1%
	if not "%paramStr%"=="" (
		shift 
		if not "%switchFlag%"=="/" (
			if not "%switchFlag%"=="-" (
				goto:parseCmdOptions
			)
		)

		:: add new command options here
		if /I "%switchName%"=="PASSIVE" set PASSIVE_MODE=true
		if /I "%switchName%"=="P"       set PASSIVE_MODE=true
		if /I "%switchName%"=="PREVIEW" set PREVIEW_MODE=true
		if /I "%switchName%"=="L"       set PREVIEW_MODE=true

		goto:parseCmdOptions
	)
	call:ForEachDrive RunAllJobFiles
goto:eof

::******************************************************************************
::-- Functions
::******************************************************************************

::------------------------------------------------------------------------------
:: Iterates over all the local drives and calls the specified function for each.
:ForEachDrive
	set callFunc=%~1
	:: local discs
	for /f "tokens=2 delims==" %%d in ('wmic logicaldisk where "drivetype=3" get name /format:value') do call:%callFunc% %%d
	:: removable discs
	:: 2^>nul to hide complaints regarding no drives matching the criteria
	for /f "tokens=2 delims==" %%d in ('wmic logicaldisk where "drivetype=2" get name /format:value 2^>nul') do call:%callFunc% %%d
goto:eof

::------------------------------------------------------------------------------
:: Iterate over all rbobcopy job file at the root of the specified drive and run 
:: them.
:RunAllJobFiles
	set jobsPath=%~1
	:: 2^>nul to hide complaints regarding empty drives
	for /f %%f in ('dir /B /A %jobsPath%\*%ROBOJOB_EXT% 2^>nul') do call:RunJobFile %jobsPath%\%%f 
goto:eof

::------------------------------------------------------------------------------
:: Performs a robocopy, using the specified job file to denote what is copied.
::
:: @param1 jobFilePath   A file path detailing the robocopy job to run.
:RunJobFile
	set jobFilePath=%~1
	set jobFilename=%~n1
	set logFilePath=%LOG_PATH_PREFIX%%jobFilename%.log

	:: set variables that we can use for expansion of the job files 
	set DRIVELETTER=%~d1

	:: for the job file, replace any variables marked for expansion (any names wrapped in %% marks)
	call:ExpandJobFile %jobFilePath% %TEMP_JOB_FILEPATH%

	::              /S :: copy Subdirectories, but not empty ones.
	::              /E :: copy subdirectories, including Empty ones.
	::        /COPYALL :: COPY ALL file info (equivalent to /COPY:DATSOU).
	::             /XO :: eXclude Older files.
	::              /Z :: copy files in restartable mode.
	::            /R:n :: number of Retries on failed copies: default 1 million.
	::            /W:n :: Wait time between retries: default is 30 seconds.
	::       /LOG:file :: output status to LOG file (overwrite existing log).
	:: /XA:[RASHCNETO] :: eXclude files with any of the given Attributes set.
	::         /MT[:n] :: Do multi-threaded copies with n threads (default 8).
	::                    n must be at least 1 and not greater than 128.
	::                    This option is incompatible with the /IPG and /EFSRAW options.
	::                    Redirect output using /LOG option for better performance.
	::          /MON:n :: MONitor source; run again when more than n changes seen.
	::          /MOT:m :: MOnitor source; run again in m minutes Time, if changed.
	set roboOptions=/JOB:%TEMP_JOB_FILEPATH% /S /COPYALL /XO /Z /R:3 /W:6 /MT

	if "%PREVIEW_MODE%"=="true" (
		set roboOptions=%roboOptions% /L
	) else (
		set roboOptions=%roboOptions% /LOG:%logFilePath% 
	)

	if "%PASSIVE_MODE%"=="true" (
		:: /B  Start application without creating a new window.
		start /b cmd /c robocopy %roboOptions% /MON:1 /MOT:%PASSIVE_REFRESH_PERIOD%
	) else (
		robocopy %roboOptions%
	)
	
goto:eof

::------------------------------------------------------------------------------
:: Invokes variable expansion by copying the supplied string to the specified 
:: file.
::
:: @param1 fileLine  A string that you want variable expansion applied to.
:: @param2 filePath  A file path, denoting the file that you want the expanded string saved to.
:ExpandFileLine
	set fileLine=%~1
	set filePath=%~2
	echo %fileLine% >> %filePath%
goto:eof

::------------------------------------------------------------------------------
:: Invokes variable expansion for an entire file, by copying line by line of 
:: that file to another temp file.
::
:: @param1 jobFile   A path denoting a text file that you want variable expansion applied to.
:: @param2 tempFile  A file path, detailing where you want the expanded version of the file saved.
:ExpandJobFile
	set jobFile=%~1
	set tempFile=%~2

	echo. > %tempFile%
	for /f "delims=" %%i in (%jobFile%) do call:ExpandFileLine "%%i" %tempFile%
goto:eof
