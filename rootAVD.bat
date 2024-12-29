@echo off
setlocal EnableDelayedExpansion
title RootAVD - Android Virtual Device Root Tool

REM Check if arguments were provided
if "%~1"=="" goto :ShowMenu

REM ################################################################################
REM #
REM # RootAVD - Android Virtual Device Root Tool
REM # Version: 2.2.0
REM # Author: jpshag
REM # Credits: Original concept by topjohnwu, modified by NewBit XDA
REM # Updated: 2024
REM #
REM # Description: 
REM # Advanced tool to root Android Virtual Devices (AVD) using Magisk
REM # Supports Android API levels 25-34+ (Android 7.1-15)
REM #
REM ################################################################################

REM Global Constants
set "VERSION=2.2.0"
set "MAGISK_VERSION=28.1"
set "MAGISK_CANARY_VERSION=28.1-4a31a74f"
set "TRUE=1"
set "FALSE=0"
set "SUCCESS=0"
set "ERROR=1"
set "MAX_RETRIES=3"
set "RETRY_DELAY=5"

REM URLs for downloads
set "MAGISK_STABLE_URL=https://github.com/topjohnwu/Magisk/releases/download/v!MAGISK_VERSION!/Magisk-v!MAGISK_VERSION!.apk"
set "MAGISK_CANARY_URL=https://raw.githubusercontent.com/topjohnwu/magisk-files/canary/app-debug.apk"
REM Default Settings
set "DEBUG_MODE=!FALSE!"
set "PATCH_FSTAB=!FALSE!"
set "GET_USB_MODULE=!FALSE!"
set "FAKE_BOOT=!FALSE!"
set "INSTALL_APPS=!FALSE!"
set "LIST_AVDS=!FALSE!"
set "RESTORE_MODE=!FALSE!"
set "KERNEL_MODULES=!FALSE!"
set "PREBUILT_KERNEL=!FALSE!"
set "ELEVATED_COPY=!FALSE!"
set "USE_CANARY=!FALSE!"
set "ALLOW_PERMISSIONS=!FALSE!"

REM Added from rootAVD.sh - Environment Detection
set "IS_64BIT=!FALSE!"
set "IS_64BIT_ONLY=!FALSE!"
set "IS_32BIT_ONLY=!FALSE!"
set "SYSTEM_ROOT=!FALSE!"
set "RECOVERY_MODE=!FALSE!"
set "KEEP_VERITY=!FALSE!"
set "KEEP_FORCE_ENCRYPT=!FALSE!"

REM Environment Setup
call :SetColors
call :InitializeEnvironment
call :ParseArguments %*
call :ValidateEnvironment

REM Main Execution
if !DEBUG_MODE! equ !TRUE! (
    call :PrintDebugInfo
)

if !LIST_AVDS! equ !TRUE! (
    call :ListAvailableAVDs
    exit /b !SUCCESS!
)

if !INSTALL_APPS! equ !TRUE! (
    call :InstallApplications
    exit /b !SUCCESS!
)

if !RESTORE_MODE! equ !TRUE! (
    call :RestoreBackups
    exit /b !SUCCESS!
)

REM Main Root Process
call :ValidateADBConnection || exit /b !ERROR!
call :PrepareWorkspace || exit /b !ERROR!
call :ProcessRamdisk || exit /b !ERROR!
call :InstallMagisk || exit /b !ERROR!
call :FinalizeInstallation || exit /b !ERROR!

echo !GREEN![✓] Root process completed successfully!!ESC!
exit /b !SUCCESS!

REM ################################################################################
REM # Function Definitions
REM ################################################################################

:SetColors
set "ESC="
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "MAGENTA=[95m"
set "CYAN=[96m"
set "WHITE=[97m"
set "BOLD=[1m"
exit /b 0

:InitializeEnvironment
    set "SCRIPT_DIR=%~dp0"
    set "MAGISK_ZIP=!SCRIPT_DIR!Magisk.zip"
    set "WORK_DIR=/data/local/tmp/rootavd"
    set "APPS_DIR=!SCRIPT_DIR!Apps"
    set "TEMP_DIR=!SCRIPT_DIR!temp"
    
    REM Create necessary directories
    if not exist "!APPS_DIR!" mkdir "!APPS_DIR!"
    if not exist "!TEMP_DIR!" mkdir "!TEMP_DIR!"
    
    REM Detect Android SDK location
    if defined ANDROID_HOME (
        set "SDK_ROOT=!ANDROID_HOME!"
    ) else if exist "%LOCALAPPDATA%\Android\Sdk" (
        set "SDK_ROOT=%LOCALAPPDATA%\Android\Sdk"
    ) else (
        echo !RED![✗] Android SDK not found. Please set ANDROID_HOME environment variable.!ESC!
        exit /b !ERROR!
    )
    
    REM Validate platform-tools
    if not exist "!SDK_ROOT!\platform-tools\adb.exe" (
        echo !RED![✗] ADB not found. Please install Android SDK platform-tools.!ESC!
        exit /b !ERROR!
    )
    
    REM Set PATH for ADB
    set "PATH=!SDK_ROOT!\platform-tools;!PATH!"
    
    REM Check for PowerShell (needed for downloads)
    powershell -Command "exit" >nul 2>&1 || (
        echo !RED![✗] PowerShell is required but not found.!ESC!
        exit /b !ERROR!
    )
    
    REM Check for curl (alternative download method)
    where curl >nul 2>&1 || (
        echo !YELLOW![!] curl not found, will use PowerShell for downloads.!ESC!
    )
exit /b !SUCCESS!

:DownloadMagisk
    echo !CYAN![*] Downloading Magisk...!ESC!
    
    set "DOWNLOAD_URL=!MAGISK_STABLE_URL!"
    if !USE_CANARY! equ !TRUE! (
        set "DOWNLOAD_URL=!MAGISK_CANARY_URL!"
    )
    
    set "TEMP_APK=!TEMP_DIR!\magisk.apk"
    set "TEMP_ZIP=!TEMP_DIR!\magisk.zip"
    
    REM Download APK
    powershell -Command "& {$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '!DOWNLOAD_URL!' -OutFile '!TEMP_APK!'}" || (
        echo !RED![✗] Failed to download Magisk!ESC!
        exit /b !ERROR!
    )
    
    REM Rename APK to ZIP
    move /y "!TEMP_APK!" "!MAGISK_ZIP!" >nul || (
        echo !RED![✗] Failed to prepare Magisk.zip!ESC!
        exit /b !ERROR!
    )
    
    echo !GREEN![✓] Magisk downloaded successfully!ESC!
exit /b !SUCCESS!

:InstallUSBModule
    echo !CYAN![*] Installing USB Host Permissions Module...!ESC!
    
    set "MODULE_ZIP=!TEMP_DIR!\usbhostpermissions.zip"
    
    REM Download module
    powershell -Command "& {$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '!USB_MODULE_URL!' -OutFile '!MODULE_ZIP!'}" || (
        echo !RED![✗] Failed to download USB module!ESC!
        exit /b !ERROR!
    )
    
    REM Push and install module
    adb push "!MODULE_ZIP!" "/sdcard/Download/" >nul 2>&1 || (
        echo !RED![✗] Failed to push USB module!ESC!
        exit /b !ERROR!
    )
    
    echo !GREEN![✓] USB Host Permissions Module installed!ESC!
    echo !YELLOW![i] Install the module through Magisk Manager after reboot!ESC!
exit /b !SUCCESS!

:InstallApplications
    echo !CYAN![*] Installing APKs from Apps folder...!ESC!
    
    set "APK_COUNT=0"
    for %%f in ("!APPS_DIR!\*.apk") do set /a APK_COUNT+=1
    
    if !APK_COUNT! equ 0 (
        echo !YELLOW![!] No APKs found in Apps folder!ESC!
        exit /b !SUCCESS!
    )
    
    for %%f in ("!APPS_DIR!\*.apk") do (
        echo !CYAN![*] Installing %%~nxf...!ESC!
        adb install -r -d "%%f" >nul 2>&1 || (
            echo !RED![✗] Failed to install %%~nxf!ESC!
            continue
        )
        echo !GREEN![✓] Installed %%~nxf!ESC!
    )
exit /b !SUCCESS!

:ListAvailableAVDs
    echo !CYAN![*] Searching for AVDs...!ESC!
    
    set "AVD_COUNT=0"
    for /f "delims=" %%i in ('dir /b /s "!SDK_ROOT!\system-images\*\ramdisk*.img" 2^>nul') do (
        set /a AVD_COUNT+=1
        set "AVD_PATH=%%i"
        setlocal enabledelayedexpansion
        echo !GREEN![!AVD_COUNT!]!ESC! !AVD_PATH:%SDK_ROOT%=!
        endlocal
    )
    
    if !AVD_COUNT! equ 0 (
        echo !YELLOW![!] No AVDs found!ESC!
        exit /b !ERROR!
    )
exit /b !SUCCESS!

:PatchFstab
    echo !CYAN![*] Patching fstab...!ESC!
    
    REM Extract ramdisk
    adb shell "cd !WORK_DIR! && mkdir ramdisk && cd ramdisk && zcat ../ramdisk.img | cpio -i" >nul 2>&1 || (
        echo !RED![✗] Failed to extract ramdisk!ESC!
        exit /b !ERROR!
    )
    
    REM Patch fstab.ranchu
    adb shell "cd !WORK_DIR!/ramdisk && echo '/dev/block/sda1 /data ext4 noatime,nosuid,nodev,barrier=1,noauto_da_alloc 0 0' >> fstab.ranchu" || (
        echo !RED![✗] Failed to patch fstab!ESC!
        exit /b !ERROR!
    )
    
    REM Repack ramdisk
    adb shell "cd !WORK_DIR!/ramdisk && find . | cpio -o -H newc | gzip > ../ramdisk.img" || (
        echo !RED![✗] Failed to repack ramdisk!ESC!
        exit /b !ERROR!
    )
    
    echo !GREEN![✓] Fstab patched successfully!ESC!
exit /b !SUCCESS!

:ValidateEnvironment
    if not defined RAMDISK_PATH (
        if not !INSTALL_APPS! equ !TRUE! if not !LIST_AVDS! equ !TRUE! (
            echo !RED![✗] No ramdisk.img path specified!ESC!
            call :ShowHelp
            exit /b !ERROR!
        )
    )
    
    if not exist "!MAGISK_ZIP!" (
        echo !YELLOW![!] Magisk.zip not found. Will attempt to download...!ESC!
        call :DownloadMagisk || exit /b !ERROR!
    )
exit /b !SUCCESS!

:ValidateADBConnection
    echo !CYAN![*] Validating ADB connection...!ESC!
    
    set "RETRY_COUNT=0"
    set "MAX_RETRIES=3"
    
    :RetryADB
    adb get-state >nul 2>&1
    if !ERRORLEVEL! neq 0 (
        set /a RETRY_COUNT+=1
        if !RETRY_COUNT! lss !MAX_RETRIES! (
            echo !YELLOW![!] ADB connection failed. Retrying (!RETRY_COUNT!/!MAX_RETRIES!)...!ESC!
            timeout /t 2 >nul
            goto :RetryADB
        )
        echo !RED![✗] ADB connection failed after !MAX_RETRIES! attempts!ESC!
        exit /b !ERROR!
    )
    
    echo !GREEN![✓] ADB connection established!ESC!
exit /b !SUCCESS!

:PrepareWorkspace
    echo !CYAN![*] Preparing workspace...!ESC!
    
    REM Clean previous workspace
    adb shell "rm -rf !WORK_DIR!" >nul 2>&1
    adb shell "mkdir -p !WORK_DIR!" >nul 2>&1
    
    REM Push required files
    adb push "!MAGISK_ZIP!" "!WORK_DIR!/" >nul 2>&1 || (
        echo !RED![✗] Failed to push Magisk.zip!ESC!
        exit /b !ERROR!
    )
    
    echo !GREEN![✓] Workspace prepared!ESC!
exit /b !SUCCESS!

:ProcessRamdisk
    echo !CYAN![*] Processing ramdisk...!ESC!
    
    REM Create backup
    call :CreateBackup "!RAMDISK_PATH!" || exit /b !ERROR!
    
    REM Push ramdisk
    adb push "!RAMDISK_PATH!" "!WORK_DIR!/ramdisk.img" >nul 2>&1 || (
        echo !RED![✗] Failed to push ramdisk!ESC!
        exit /b !ERROR!
    )
    
    if !PATCH_FSTAB! equ !TRUE! (
        call :PatchFstab || exit /b !ERROR!
    )
    
    echo !GREEN![✓] Ramdisk processed!ESC!
exit /b !SUCCESS!

:InstallMagisk
    echo !CYAN![*] Installing Magisk...!ESC!
    
    REM Extract Magisk
    adb shell "cd !WORK_DIR! && unzip -o Magisk.zip" >nul 2>&1 || (
        echo !RED![✗] Failed to extract Magisk!ESC!
        exit /b !ERROR!
    )
    
    REM Patch ramdisk
    adb shell "cd !WORK_DIR! && sh boot_patch.sh ramdisk.img" >nul 2>&1 || (
        echo !RED![✗] Failed to patch ramdisk!ESC!
        exit /b !ERROR!
    )
    
    REM Pull patched ramdisk
    adb pull "!WORK_DIR!/new-ramdisk.img" "!RAMDISK_PATH!" >nul 2>&1 || (
        echo !RED![✗] Failed to pull patched ramdisk!ESC!
        exit /b !ERROR!
    )
    
    echo !GREEN![✓] Magisk installed!ESC!
exit /b !SUCCESS!

:FinalizeInstallation
    echo !CYAN![*] Finalizing installation...!ESC!
    
    REM Install additional modules if requested
    if !GET_USB_MODULE! equ !TRUE! (
        call :InstallUSBModule || exit /b !ERROR!
    )
    
    if !KERNEL_MODULES! equ !TRUE! (
        call :InstallKernelModules || exit /b !ERROR!
    )
    
    REM Clean up
    adb shell "rm -rf !WORK_DIR!" >nul 2>&1
    
    echo !GREEN![✓] Installation finalized!ESC!
    echo !MAGENTA![i] Please reboot your AVD to complete the root process!ESC!
exit /b !SUCCESS!

:CreateBackup
    set "FILE=%~1"
    set "BACKUP=!FILE!.backup"
    
    if not exist "!BACKUP!" (
        echo !CYAN![*] Creating backup of !FILE!...!ESC!
        copy "!FILE!" "!BACKUP!" >nul 2>&1 || (
            echo !RED![✗] Failed to create backup!ESC!
            exit /b !ERROR!
        )
        echo !GREEN![✓] Backup created!ESC!
    )
exit /b !SUCCESS!

:RestoreBackups
    echo !CYAN![*] Restoring backups...!ESC!
    
    for %%f in (*.backup) do (
        set "ORIGINAL=%%~nf"
        echo !CYAN![*] Restoring %%f to !ORIGINAL!...!ESC!
        copy "%%f" "!ORIGINAL!" >nul 2>&1 || (
            echo !RED![✗] Failed to restore %%f!ESC!
            continue
        )
    )
    
    echo !GREEN![✓] Backups restored!ESC!
exit /b !SUCCESS!

:ShowHelp
    echo !CYAN!!BOLD!RootAVD v!VERSION! - Android Virtual Device Root Tool!ESC!
    echo.
    echo !YELLOW!Description:!ESC!
    echo   Advanced tool to root Android Virtual Devices (AVD) using Magisk v!MAGISK_VERSION!
    echo.
    echo !YELLOW!Usage:!ESC!
    echo   rootAVD.bat [ramdisk.img] [OPTIONS] [EXTRA]
    echo.
    echo !YELLOW!Options:!ESC!
    echo   restore                    Restore backup files
    echo   InstallKernelModules      Install custom kernel modules
    echo   InstallPrebuiltKernelModules  Install prebuilt kernel modules
    echo.
    echo !YELLOW!Extra Arguments:!ESC!
    echo   DEBUG                      Enable debug mode
    echo   PATCHFSTAB                Patch fstab for additional mounts
    echo   GetUSBHPmodZ              Download USB Host Permissions module
    echo   FAKEBOOTIMG               Create fake boot image for Magisk
    echo   InstallApps               Install APKs from Apps folder
    echo   ListAllAVDs               List all available AVDs
    echo   CANARY                    Use Magisk Canary (!MAGISK_CANARY_VERSION!) instead of stable
    echo.
    echo !YELLOW!Examples:!ESC!
    echo   rootAVD.bat system-images\android-30\google_apis_playstore\x86_64\ramdisk.img
    echo   rootAVD.bat ramdisk.img PATCHFSTAB
    echo   rootAVD.bat ListAllAVDs
    echo   rootAVD.bat ramdisk.img CANARY GetUSBHPmodZ
    echo.
    echo !YELLOW!Notes:!ESC!
    echo   - Creates backups automatically before modifications
    echo   - Supports Android 7.1 through 15
    echo   - USB module requires manual installation through Magisk after reboot
    echo   - APKs in the Apps folder will be installed automatically
exit /b !SUCCESS!

:ParseArguments
    set "ARGS=%*"
    if "!ARGS!"=="" (
        call :ShowHelp
        exit /b !SUCCESS!
    )
    
    REM Parse flags
    echo.!ARGS! | findstr /I "DEBUG" >nul && set "DEBUG_MODE=!TRUE!"
    echo.!ARGS! | findstr /I "PATCHFSTAB" >nul && set "PATCH_FSTAB=!TRUE!"
    echo.!ARGS! | findstr /I "GetUSBHPmodZ" >nul && set "GET_USB_MODULE=!TRUE!"
    echo.!ARGS! | findstr /I "FAKEBOOTIMG" >nul && set "FAKE_BOOT=!TRUE!"
    echo.!ARGS! | findstr /I "InstallApps" >nul && set "INSTALL_APPS=!TRUE!"
    echo.!ARGS! | findstr /I "ListAllAVDs" >nul && set "LIST_AVDS=!TRUE!"
    echo.!ARGS! | findstr /I "CANARY" >nul && set "USE_CANARY=!TRUE!"
    
    REM Parse options
    for %%a in (%*) do (
        if "%%a"=="restore" set "RESTORE_MODE=!TRUE!"
        if "%%a"=="InstallKernelModules" set "KERNEL_MODULES=!TRUE!"
        if "%%a"=="InstallPrebuiltKernelModules" set "PREBUILT_KERNEL=!TRUE!"
    )
    
    REM Get ramdisk path
    for %%a in (%*) do (
        echo %%a | findstr /I "ramdisk.*\.img" >nul && (
            set "RAMDISK_PATH=%%a"
        )
    )
exit /b !SUCCESS!

:PrintDebugInfo
    echo !YELLOW!!BOLD![DEBUG] Configuration:!ESC!
    echo   Version: !VERSION!
    echo   Magisk Version: !MAGISK_VERSION! ^(Canary: !MAGISK_CANARY_VERSION!^)
    echo   Debug Mode: !DEBUG_MODE!
    echo   Patch Fstab: !PATCH_FSTAB!
    echo   USB Module: !GET_USB_MODULE!
    echo   Fake Boot: !FAKE_BOOT!
    echo   Install Apps: !INSTALL_APPS!
    echo   List AVDs: !LIST_AVDS!
    echo   Restore Mode: !RESTORE_MODE!
    echo   Kernel Modules: !KERNEL_MODULES!
    echo   Prebuilt Kernel: !PREBUILT_KERNEL!
    echo   Use Canary: !USE_CANARY!
    echo.
    echo !YELLOW!Paths:!ESC!
    echo   Ramdisk: !RAMDISK_PATH!
    echo   SDK Root: !SDK_ROOT!
    echo   Script Dir: !SCRIPT_DIR!
    echo   Work Dir: !WORK_DIR!
    echo   Apps Dir: !APPS_DIR!
    echo   Temp Dir: !TEMP_DIR!
    echo.
    echo !YELLOW!URLs:!ESC!
    echo   Stable: !MAGISK_STABLE_URL!
    echo   Canary: !MAGISK_CANARY_URL!
    echo   USB Module: !USB_MODULE_URL!
    echo.
exit /b !SUCCESS!

:CreateFakeBootImage
    echo !CYAN![*] Creating fake boot image...!ESC!
    
    REM Create fake boot image
    adb shell "cd !WORK_DIR! && dd if=/dev/zero of=fakeboot.img bs=1M count=100" >nul 2>&1 || (
        echo !RED![✗] Failed to create fake boot image!ESC!
        exit /b !ERROR!
    )
    
    REM Add basic headers
    adb shell "cd !WORK_DIR! && mkbootimg --kernel /system/kernel --ramdisk ramdisk.img -o fakeboot.img" >nul 2>&1 || (
        echo !RED![✗] Failed to add boot headers!ESC!
        exit /b !ERROR!
    )
    
    REM Move to download folder
    adb shell "mv !WORK_DIR!/fakeboot.img /sdcard/Download/" >nul 2>&1 || (
        echo !RED![✗] Failed to move boot image!ESC!
        exit /b !ERROR!
    )
    
    echo !GREEN![✓] Fake boot image created at /sdcard/Download/fakeboot.img!ESC!
    
    REM Launch Magisk if requested
    if !FAKE_BOOT! equ !TRUE! (
        echo !CYAN![*] Launching Magisk to patch boot image...!ESC!
        adb shell am start -n com.topjohnwu.magisk/.ui.MainActivity
        echo !YELLOW![i] Please patch the boot image in Magisk within 60 seconds...!ESC!
        timeout /t 60 /nobreak >nul
    )
exit /b !SUCCESS!

:InstallKernelModules
    echo !CYAN![*] Installing kernel modules...!ESC!
    
    set "BZIMAGE=!SCRIPT_DIR!bzImage"
    set "INITRAMFS=!SCRIPT_DIR!initramfs.img"
    
    REM Validate files
    if not exist "!BZIMAGE!" (
        echo !RED![✗] bzImage not found!!ESC!
        exit /b !ERROR!
    )
    
    if not exist "!INITRAMFS!" (
        echo !RED![✗] initramfs.img not found!!ESC!
        exit /b !ERROR!
    )
    
    REM Create backup of kernel
    call :CreateBackup "!SDK_ROOT!\system-images\android-!API!\google_apis_playstore\x86_64\kernel-ranchu" || exit /b !ERROR!
    
    REM Install new kernel
    copy "!BZIMAGE!" "!SDK_ROOT!\system-images\android-!API!\google_apis_playstore\x86_64\kernel-ranchu" >nul || (
        echo !RED![✗] Failed to install kernel!ESC!
        exit /b !ERROR!
    )
    
    REM Push initramfs
    adb push "!INITRAMFS!" "!WORK_DIR!/" >nul 2>&1 || (
        echo !RED![✗] Failed to push initramfs!ESC!
        exit /b !ERROR!
    )
    
    echo !GREEN![✓] Kernel modules installed successfully!ESC!
exit /b !SUCCESS!

:DetectEnvironment
    echo !CYAN![*] Detecting environment...!ESC!
    
    REM Get device architecture
    for /f "tokens=2 delims==" %%a in ('adb shell getprop ro.product.cpu.abi') do set "ABI=%%a"
    
    if "!ABI!"=="x86" (
        set "ARCH=x86"
        set "ARCH32=x86"
        set "IS_64BIT=!FALSE!"
    ) else if "!ABI!"=="arm64-v8a" (
        set "ARCH=arm64"
        set "ARCH32=armeabi-v7a"
        set "IS_64BIT=!TRUE!"
    ) else if "!ABI!"=="x86_64" (
        set "ARCH=x64"
        set "ARCH32=x86"
        set "IS_64BIT=!TRUE!"
    ) else (
        set "ARCH=arm"
        set "ABI=armeabi-v7a"
        set "ARCH32=armeabi-v7a"
        set "IS_64BIT=!FALSE!"
    )
    
    REM Get Android version and API level
    for /f "tokens=2 delims==" %%a in ('adb shell getprop ro.build.version.sdk') do set "API=%%a"
    for /f "tokens=2 delims==" %%a in ('adb shell getprop ro.build.version.release') do set "ANDROID_VERSION=%%a"
    
    echo !GREEN![✓] Device Platform: !ARCH!!ESC!
    echo !GREEN![✓] Android Version: !ANDROID_VERSION! ^(API !API!^)!ESC!
exit /b !SUCCESS!

:AllowPermissions
    if !ALLOW_PERMISSIONS! equ !TRUE! (
        echo !CYAN![*] Allowing permissions to third-party apps...!ESC!
        for /f "tokens=2 delims=:" %%a in ('adb shell pm list packages -3') do (
            echo !CYAN![-] Granting permissions to %%a!ESC!
            adb shell appops set %%a MANAGE_EXTERNAL_STORAGE allow >nul 2>&1
        )
    )
exit /b !SUCCESS!

:VerifyRamdiskOrigin
    echo !CYAN![*] Verifying ramdisk origin...!ESC!
    
    REM Get AVD kernel version
    for /f "tokens=*" %%a in ('adb shell uname -r') do set "AVD_KERNEL=%%a"
    
    REM Get ramdisk kernel version
    for /f "tokens=*" %%a in ('adb shell "cat /data/local/tmp/rootavd/ramdisk.cpio | strings | grep -m 1 vermagic= | sed 's/vermagic=//;s/ .*$//'"') do set "RAMDISK_KERNEL=%%a"
    
    echo !CYAN![-] AVD Kernel: !AVD_KERNEL!!ESC!
    echo !CYAN![-] Ramdisk Kernel: !RAMDISK_KERNEL!!ESC!
    
    if "!AVD_KERNEL!"=="!RAMDISK_KERNEL!" (
        echo !GREEN![✓] Ramdisk matches this AVD!ESC!
    ) else (
        echo !YELLOW![!] Warning: Ramdisk may not be from this AVD!ESC!
    )
exit /b !SUCCESS!

:ShowMenu
cls
call :SetColors
echo +----------------------------------------+
echo ^|        RootAVD - Interactive Menu        ^|
echo +----------------------------------------+
echo.
echo Select an option:
echo.
echo [1] Root AVD (Select ramdisk.img)
echo [2] List Available AVDs
echo [3] Install Apps from Apps folder
echo [4] Restore Backups
echo [5] Advanced Options
echo [6] Show Help
echo [7] Exit
echo.
set /p "choice=Enter your choice (1-7): "

if "%choice%"=="1" goto :MenuRootAVD
if "%choice%"=="2" goto :MenuListAVDs
if "%choice%"=="3" goto :MenuInstallApps
if "%choice%"=="4" goto :MenuRestore
if "%choice%"=="5" goto :MenuAdvanced
if "%choice%"=="6" goto :MenuHelp
if "%choice%"=="7" exit /b 0
goto :ShowMenu

:MenuRootAVD
cls
echo !CYAN!!BOLD!Select ramdisk.img file!ESC!
echo.
set "psCommand="(new-object -COM 'Shell.Application').BrowseForFolder(0,'Select the folder containing ramdisk.img',0,0).self.path""
for /f "usebackq delims=" %%i in (`powershell %psCommand%`) do set "folder=%%i"
if "!folder!"=="" goto :ShowMenu

set "RAMDISK_PATH="
for /f "delims=" %%i in ('dir /b /s "!folder!\ramdisk*.img" 2^>nul') do set "RAMDISK_PATH=%%i"

if "!RAMDISK_PATH!"=="" (
    echo !RED![✗] No ramdisk.img found in selected folder!!ESC!
    timeout /t 3 >nul
    goto :ShowMenu
)

echo !GREEN![✓] Found: !RAMDISK_PATH!!ESC!
echo.
echo !YELLOW!Additional options:!ESC!
echo !GREEN![1]!ESC! Root with default settings
echo !GREEN![2]!ESC! Root with USB module
echo !GREEN![3]!ESC! Root with USB module and fstab patch
echo !GREEN![4]!ESC! Root with Magisk Canary
echo !GREEN![5]!ESC! Back to main menu
echo.
set /p "subchoice=!CYAN!Enter your choice (1-5): !ESC!"

if "!subchoice!"=="1" call :ProcessRoot "!RAMDISK_PATH!"
if "!subchoice!"=="2" call :ProcessRoot "!RAMDISK_PATH!" GetUSBHPmodZ
if "!subchoice!"=="3" call :ProcessRoot "!RAMDISK_PATH!" GetUSBHPmodZ PATCHFSTAB
if "!subchoice!"=="4" call :ProcessRoot "!RAMDISK_PATH!" CANARY
if "!subchoice!"=="5" goto :ShowMenu
goto :ShowMenu

:MenuListAVDs
cls
call :ListAvailableAVDs
echo.
echo !YELLOW!Press any key to return to menu...!ESC!
pause >nul
goto :ShowMenu

:MenuInstallApps
cls
call :InstallApplications
echo.
echo !YELLOW!Press any key to return to menu...!ESC!
pause >nul
goto :ShowMenu

:MenuRestore
cls
call :RestoreBackups
echo.
echo !YELLOW!Press any key to return to menu...!ESC!
pause >nul
goto :ShowMenu

:MenuAdvanced
cls
echo !CYAN!!BOLD!Advanced Options!ESC!
echo.
echo !GREEN![1]!ESC! Install Kernel Modules
echo !GREEN![2]!ESC! Install Prebuilt Kernel Modules
echo !GREEN![3]!ESC! Create Fake Boot Image
echo !GREEN![4]!ESC! Debug Mode
echo !GREEN![5]!ESC! Back to main menu
echo.
set /p "advchoice=!CYAN!Enter your choice (1-5): !ESC!"

if "!advchoice!"=="1" set "KERNEL_MODULES=!TRUE!" && call :InstallKernelModules
if "!advchoice!"=="2" set "PREBUILT_KERNEL=!TRUE!" && call :InstallKernelModules
if "!advchoice!"=="3" set "FAKE_BOOT=!TRUE!" && call :CreateFakeBootImage
if "!advchoice!"=="4" set "DEBUG_MODE=!TRUE!" && call :PrintDebugInfo
if "!advchoice!"=="5" goto :ShowMenu
echo.
echo !YELLOW!Press any key to return to menu...!ESC!
pause >nul
goto :ShowMenu

:MenuHelp
cls
call :ShowHelp
echo.
echo !YELLOW!Press any key to return to menu...!ESC!
pause >nul
goto :ShowMenu

:ProcessRoot
set "RAMDISK_PATH=%~1"
shift
:ProcessRootLoop
if "%~1"=="" goto :ProcessRootExec
set "%~1=!TRUE!"
shift
goto :ProcessRootLoop

:ProcessRootExec
call :ValidateADBConnection || goto :ShowMenu
call :PrepareWorkspace || goto :ShowMenu
call :ProcessRamdisk || goto :ShowMenu
call :InstallMagisk || goto :ShowMenu
call :FinalizeInstallation || goto :ShowMenu
echo.
echo !YELLOW!Press any key to return to menu...!ESC!
pause >nul
goto :ShowMenu
