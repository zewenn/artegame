; ==============================================================================
; AMRAP - Windows Installer Script (NSIS)
; ==============================================================================

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"

; ------------------------------------------------------------------------------
; Default Definitions (Can be overridden via /D command-line arguments)
; ------------------------------------------------------------------------------
!ifndef REPO_ROOT
  !define REPO_ROOT "../.."
!endif

!ifndef VERSION
  !define VERSION "3.0.0"
!endif

!ifndef BIN_DIR
  !define BIN_DIR "${REPO_ROOT}/zig-out/bin"
!endif

!ifndef OUTPUT_DIR
  !define OUTPUT_DIR "${REPO_ROOT}/zig-out/bin"
!endif

!ifndef OUTPUT_NAME
  !define OUTPUT_NAME "amrap-windows-x86_64-setup.exe"
!endif

!ifndef ICON_PATH
  !define ICON_PATH "${REPO_ROOT}/src/assets/ui/branding/icon.ico"
!endif

; ------------------------------------------------------------------------------
; General Configuration
; ------------------------------------------------------------------------------
Name "AMRAP"
Caption "AMRAP ${VERSION} Setup"
OutFile "${OUTPUT_DIR}\${OUTPUT_NAME}"
Unicode True
SetCompressor /SOLID lzma

; Per-user install: no Administrator UAC prompt needed, installs to user's LocalAppData
RequestExecutionLevel user

; Default installation directory
InstallDir "$LOCALAPPDATA\Programs\AMRAP"
InstallDirRegKey HKCU "Software\AMRAP" "InstallDir"

; ------------------------------------------------------------------------------
; Modern UI 2 Settings & Icons
; ------------------------------------------------------------------------------
!define MUI_ABORTWARNING
!define MUI_ICON "${ICON_PATH}"
!define MUI_UNICON "${ICON_PATH}"

; ------------------------------------------------------------------------------
; Installer Wizard Pages
; ------------------------------------------------------------------------------
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

; Finish page allows launching the game immediately
!define MUI_FINISHPAGE_RUN "$INSTDIR\amrap.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Launch AMRAP"
!insertmacro MUI_PAGE_FINISH

; ------------------------------------------------------------------------------
; Uninstaller Wizard Pages
; ------------------------------------------------------------------------------
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; ------------------------------------------------------------------------------
; Language
; ------------------------------------------------------------------------------
!insertmacro MUI_LANGUAGE "English"

; ------------------------------------------------------------------------------
; Installation Section
; ------------------------------------------------------------------------------
Section "AMRAP (required)" SecMain
    SectionIn RO

    ; Set destination directory
    SetOutPath "$INSTDIR"

    ; Main executable
    File "${BIN_DIR}\amrap.exe"

    ; Game assets directory
    File /r "${BIN_DIR}\assets"

    ; Include src/assets directory if present in staging (for relative path compatibility)
    !if /FILEEXISTS "${BIN_DIR}\src\*.*"
        File /r "${BIN_DIR}\src"
    !endif

    ; Create uninstaller executable
    WriteUninstaller "$INSTDIR\Uninstall.exe"

    ; Start Menu Shortcuts
    CreateDirectory "$SMPROGRAMS\AMRAP"
    CreateShortcut "$SMPROGRAMS\AMRAP\AMRAP.lnk" "$INSTDIR\amrap.exe" "" "$INSTDIR\amrap.exe" 0 SW_SHOWNORMAL "" "AMRAP"
    CreateShortcut "$SMPROGRAMS\AMRAP\Uninstall AMRAP.lnk" "$INSTDIR\Uninstall.exe" "" "$INSTDIR\Uninstall.exe" 0 SW_SHOWNORMAL "" "Uninstall AMRAP"

    ; Desktop Shortcut
    CreateShortcut "$DESKTOP\AMRAP.lnk" "$INSTDIR\amrap.exe" "" "$INSTDIR\amrap.exe" 0 SW_SHOWNORMAL "" "AMRAP"

    ; Store installation folder in registry
    WriteRegStr HKCU "Software\AMRAP" "InstallDir" "$INSTDIR"

    ; Register in Windows "Installed apps" / "Add or Remove Programs"
    !define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\AMRAP"
    WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "AMRAP"
    WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\amrap.exe,0"
    WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion" "${VERSION}"
    WriteRegStr HKCU "${UNINST_KEY}" "Publisher" "zewenn"
    WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
    WriteRegStr HKCU "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
    WriteRegStr HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
    WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
    WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1

    ; Estimate installed size in KB
    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKCU "${UNINST_KEY}" "EstimatedSize" "$0"
SectionEnd

; ------------------------------------------------------------------------------
; Uninstallation Section
; ------------------------------------------------------------------------------
Section "Uninstall"
    ; Remove shortcuts
    Delete "$DESKTOP\AMRAP.lnk"
    Delete "$SMPROGRAMS\AMRAP\AMRAP.lnk"
    Delete "$SMPROGRAMS\AMRAP\Uninstall AMRAP.lnk"
    RMDir "$SMPROGRAMS\AMRAP"

    ; Remove files and directories
    Delete "$INSTDIR\amrap.exe"
    Delete "$INSTDIR\Uninstall.exe"
    RMDir /r "$INSTDIR\assets"
    RMDir /r "$INSTDIR\src"

    ; Remove root install folder if empty
    RMDir "$INSTDIR"

    ; Remove registry keys
    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\AMRAP"
    DeleteRegKey HKCU "Software\AMRAP"
SectionEnd
