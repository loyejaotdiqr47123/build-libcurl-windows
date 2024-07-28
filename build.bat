@echo off
setlocal EnableDelayedExpansion

REM Function to find Visual Studio installation path
:find_vs_path
set "VSWHERE_PATH=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE_PATH%" (
    for /f "tokens=*" %%i in ('"%VSWHERE_PATH%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath') do (
        set "VS_INSTALL_PATH=%%i"
    )
) else (
    echo "vswhere.exe not found. Please install Visual Studio Installer."
    exit /b 1
)
goto :eof

REM Find Visual Studio installation path
call :find_vs_path

REM Check if Visual Studio is installed
if not defined VS_INSTALL_PATH (
    echo "No Visual Studio installation found."
    exit /b 1
)

echo Found Visual Studio installation at: %VS_INSTALL_PATH%

REM Check for specific versions
for %%V in (2022 2019 2017) do (
    set "VCVARSALL_PATH=%VS_INSTALL_PATH%\VC\Auxiliary\Build\vcvarsall.bat"
    if exist "%VCVARSALL_PATH%" (
        set "COMPILER_VER=%%V"
        echo Using Visual Studio %%V
        goto setup_env
    )
)

REM If no specific version found, check older versions
set "OLD_VS_VERSIONS=14.0 12.0 11.0 10.0 9.0 8 VC98"
for %%V in (%OLD_VS_VERSIONS%) do (
    set "VCVARSALL_PATH=%ProgramFiles(x86)%\Microsoft Visual Studio %%V\VC\vcvarsall.bat"
    if exist "%VCVARSALL_PATH%" (
        set "COMPILER_VER=%%V"
        echo Using Visual Studio %%V
        goto setup_env
    )
)

echo No suitable Visual Studio installation found.
exit /b 1

:setup_env
echo Setting up environment for Visual Studio %COMPILER_VER%
call "%VCVARSALL_PATH%" x86

:begin
REM Setup path to helper bin
set "ROOT_DIR=%CD%"
set "RM=%CD%\bin\unxutils\rm.exe"
set "CP=%CD%\bin\unxutils\cp.exe"
set "MKDIR=%CD%\bin\unxutils\mkdir.exe"
set "SEVEN_ZIP=%CD%\bin\7-zip\7za.exe"
set "XIDEL=%CD%\bin\xidel\xidel.exe"

REM Housekeeping
"%RM%" -rf tmp_*
"%RM%" -rf third-party
"%RM%" -rf curl.zip
"%RM%" -rf build_*.txt

REM Get download url .Look under <blockquote><a type='application/zip' href='xxx'>
echo Get download url...
"%XIDEL%" https://curl.haxx.se/download.html -e "//a[@type='application/zip' and ends-with(@href, '.zip')]/@href" > tmp_url
set /p url=<tmp_url

REM exit on errors, else continue
if %errorlevel% neq 0 exit /b %errorlevel%

REM Download latest curl and rename to curl.zip
echo Downloading latest curl...
set "LOCAL_CURL=%~dp0curl.zip"
bitsadmin.exe /transfer "curltransfer" "https://curl.haxx.se%url%" "%LOCAL_CURL%"

REM Extract downloaded zip file to tmp_libcurl
"%SEVEN_ZIP%" x curl.zip -y -otmp_libcurl | FIND /V "ing  " | FIND /V "Igor Pavlov"

cd tmp_libcurl\curl-*\winbuild

if "%COMPILER_VER%" == "6" (
    set VCVERSION=6
    goto buildnow
)

if "%COMPILER_VER%" == "2005" (
    set VCVERSION=8
    goto buildnow
)

if "%COMPILER_VER%" == "2008" (
    set VCVERSION=9
    goto buildnow
)

if "%COMPILER_VER%" == "2010" (
    set VCVERSION=10
    goto buildnow
)

if "%COMPILER_VER%" == "2012" (
    set VCVERSION=11
    goto buildnow
)

if "%COMPILER_VER%" == "2013" (
    set VCVERSION=12
    goto buildnow
)

if "%COMPILER_VER%" == "2015" (
    set VCVERSION=14
    goto buildnow
)
if "%COMPILER_VER%" == "2017" (
    set VCVERSION=15
    goto buildnow
)

if "%COMPILER_VER%" == "2019" (
    set VCVERSION=16
    goto buildnow
)

if "%COMPILER_VER%" == "2022" (
    set VCVERSION=17
    goto buildnow
)

:buildnow
REM Build!
echo "Building libcurl now!"

if "%1"=="-static" (
    set RTLIBCFG=static
    echo Using /MT instead of /MD
) 

echo "Path to vcvarsall.bat: %VCVARSALL_PATH%"
call "%VCVARSALL_PATH%" x86

echo Compiling dll-debug-x86 version...
nmake /f Makefile.vc mode=dll VC=%VCVERSION% DEBUG=yes

echo Compiling dll-release-x86 version...
nmake /f Makefile.vc mode=dll VC=%VCVERSION% DEBUG=no GEN_PDB=yes

echo Compiling static-debug-x86 version...
nmake /f Makefile.vc mode=static VC=%VCVERSION% DEBUG=yes

echo Compiling static-release-x86 version...
nmake /f Makefile.vc mode=static VC=%VCVERSION% DEBUG=no

call "%VCVARSALL_PATH%" x64
echo Compiling dll-debug-x64 version...
nmake /f Makefile.vc mode=dll VC=%VCVERSION% DEBUG=yes MACHINE=x64

echo Compiling dll-release-x64 version...
nmake /f Makefile.vc mode=dll VC=%VCVERSION% DEBUG=no GEN_PDB=yes MACHINE=x64

echo Compiling static-debug-x64 version...
nmake /f Makefile.vc mode=static VC=%VCVERSION% DEBUG=yes MACHINE=x64

echo Compiling static-release-x64 version...
nmake /f Makefile.vc mode=static VC=%VCVERSION% DEBUG=no MACHINE=x64

REM Copy compiled .*lib, *.pdb, *.dll files folder to third-party\lib\dll-debug folder
cd "%ROOT_DIR%\tmp_libcurl\curl-*\builds\libcurl-vc-x86-debug-dll-ipv6-sspi-winssl"
"%MKDIR%" -p "%ROOT_DIR%\third-party\libcurl\lib\dll-debug-x86"
"%CP%" lib\*.pdb "%ROOT_DIR%\third-party\libcurl\lib\dll-debug-x86"
"%CP%" lib\*.lib "%ROOT_DIR%\third-party\libcurl\lib\dll-debug-x86"
"%CP%" bin\*.dll "%ROOT_DIR%\third-party\libcurl\lib\dll-debug-x86"

REM Copy compiled .*lib, *.pdb, *.dll files to third-party\lib\dll-release folder
cd "%ROOT_DIR%\tmp_libcurl\curl-*\builds\libcurl-vc-x86-release-dll-ipv6-sspi-winssl"
"%MKDIR%" -p "%ROOT_DIR%\third-party\libcurl\lib\dll-release-x86"
"%CP%" lib\*.pdb "%ROOT_DIR%\third-party\libcurl\lib\dll-release-x86"
"%CP%" lib\*.lib "%ROOT_DIR%\third-party\libcurl\lib\dll-release-x86"
"%CP%" bin\*.dll "%ROOT_DIR%\third-party\libcurl\lib\dll-release-x86"

REM Copy compiled .*lib file in lib-release folder to third-party\lib\static-debug folder
cd "%ROOT_DIR%\tmp_libcurl\curl-*\builds\libcurl-vc-x86-debug-static-ipv6-sspi-winssl"
"%MKDIR%" -p "%ROOT_DIR%\third-party\libcurl\lib\static-debug-x86"
"%CP%" lib\*.lib "%ROOT_DIR%\third-party\libcurl\lib\static-debug-x86"

REM Copy compiled .*lib files in lib-release folder to third-party\lib\static-release folder
cd "%ROOT_DIR%\tmp_libcurl\curl-*\builds\libcurl-vc-x86-release-static-ipv6-sspi-winssl"
"%MKDIR%" -p "%ROOT_DIR%\third-party\libcurl\lib\static-release-x86"
"%CP%" lib\*.lib "%ROOT_DIR%\third-party\libcurl\lib\static-release-x86"

REM Copy compiled .*lib, *.pdb, *.dll files folder to third-party\lib\dll-debug folder
cd "%ROOT_DIR%\tmp_libcurl\curl-*\builds\libcurl-vc-x64-debug-dll-ipv6-sspi-winssl"
"%MKDIR%" -p "%ROOT_DIR%\third-party\libcurl\lib\dll-debug-x64"
"%CP%" lib\*.pdb "%ROOT_DIR%\third-party\libcurl\lib\dll-debug-x64"
"%CP%" lib\*.lib "%ROOT_DIR%\third-party\libcurl\lib\dll-debug-x64"
"%CP%" bin\*.dll "%ROOT_DIR%\third-party\libcurl\lib\dll-debug-x64"

REM Copy compiled .*lib, *.pdb, *.dll files to third-party\lib\dll-release folder
cd "%ROOT_DIR%\tmp_libcurl\curl-*\builds\libcurl-vc-x64-release-dll-ipv6-sspi-winssl"
"%MKDIR%" -p "%ROOT_DIR%\third-party\libcurl\lib\dll-release-x64"
"%CP%" lib\*.pdb "%ROOT_DIR%\third-party\libcurl\lib\dll-release-x64"
"%CP%" lib\*.lib "%ROOT_DIR%\third-party\libcurl\lib\dll-release-x64"
"%CP%" bin\*.dll "%ROOT_DIR%\third-party\libcurl\lib\dll-release-x64"

REM Copy compiled .*lib file in lib-release folder to third-party\lib\static-debug folder
cd "%ROOT_DIR%\tmp_libcurl\curl-*\builds\libcurl-vc-x64-debug-static-ipv6-sspi-winssl"
"%MKDIR%" -p "%ROOT_DIR%\third-party\libcurl\lib\static-debug-x64"
"%CP%" lib\*.lib "%ROOT_DIR%\third-party\libcurl\lib\static-debug-x64"

REM Copy compiled .*lib files in lib-release folder to third-party\lib\static-release folder
cd "%ROOT_DIR%\tmp_libcurl\curl-*\builds\libcurl-vc-x64-release-static-ipv6-sspi-winssl"
"%MKDIR%" -p "%ROOT_DIR%\third-party\libcurl\lib\static-release-x64"
"%CP%" lib\*.lib "%ROOT_DIR%\third-party\libcurl\lib\static-release-x64"

:end
echo Done.
exit /b
