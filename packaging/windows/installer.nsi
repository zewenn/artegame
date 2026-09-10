; ==============================================================================
; Artegame - Windows Installer Script (NSIS)
; ==============================================================================

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"

; ------------------------------------------------------------------------------
; Default Definitions (Can be overridden via /D command-line arguments)
; ------------------------------------------------------------------------------
!ifndef VERSION
  !define VERSION "3.0.0"
!endif

!ifndef BIN_DIR
  !define BIN_DIR "..\..\zig-out\bin"
!endif

!ifndef OUTPUT_DIR
  !define OUTPUT_DIR "..\..\zig-out\bin"
!endif

!ifndef OUTPUT_NAME
  !define OUTPUT_NAME "artegame-windows-x86_64-setup.exe"
!endif

!ifndef ICON_PATH
  !define ICON_PATH "..\..\src\assets\ui\branding\icon.ico"
!endif

; ------------------------------------------------------------------------------
; General Configuration
; ------------------------------------------------------------------------------
Name "Artegame"
Caption "Artegame ${VERSION} Setup"
OutFile "${OUTPUT_DIR}\${OUTPUT_NAME}"
Unicode True
SetCompressor /SOLID lzma

; Per-user install: no Administrator UAC prompt needed, installs to user's LocalAppData
RequestExecutionLevel user

; Default installation directory
InstallDir "$LOCALAPPDATA\Programs\Artegame"
InstallDirRegKey HKCU "Software\Artegame" "InstallDir"

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
!define MUI_FINISHPAGE_RUN "$INSTDIR\artegame.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Launch Artegame"
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
Section "Artegame (required)" SecMain
    SectionIn RO

    ; Set destination directory
    SetOutPath "$INSTDIR"

    ; Main executable
    File "${BIN_DIR}\artegame.exe"

    ; Game assets directory
    File /r "${BIN_DIR}\assets"

    ; Include src/assets directory if present in staging (for relative path compatibility)
    !ifexists "${BIN_DIR}\src"
        File /r "${BIN_DIR}\src"
    !endif

    ; Create uninstaller executable
    WriteUninstaller "$INSTDIR\Uninstall.exe"

    ; Start Menu Shortcuts
    CreateDirectory "$SMPROGRAMS\Artegame"
    CreateShortcut "$SMPROGRAMS\Artegame\Artegame.lnk" "$INSTDIR\artegame.exe" "" "$INSTDIR\artegame.exe" 0 SW_SHOWNORMAL "" "Artegame"
    CreateShortcut "$SMPROGRAMS\Artegame\Uninstall Artegame.lnk" "$INSTDIR\Uninstall.exe" "" "$INSTDIR\Uninstall.exe" 0 SW_SHOWNORMAL "" "Uninstall Artegame"

    ; Desktop Shortcut
    CreateShortcut "$DESKTOP\Artegame.lnk" "$INSTDIR\artegame.exe" "" "$INSTDIR\artegame.exe" 0 SW_SHOWNORMAL "" "Artegame"

    ; Store installation folder in registry
    WriteRegStr HKCU "Software\Artegame" "InstallDir" "$INSTDIR"

    ; Register in Windows "Installed apps" / "Add or Remove Programs"
    !define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Artegame"
    WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "Artegame"
    WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\artegame.exe,0"
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
    Delete "$DESKTOP\Artegame.lnk"
    Delete "$SMPROGRAMS\Artegame\Artegame.lnk"
    Delete "$SMPROGRAMS\Artegame\Uninstall Artegame.lnk"
    RMDir "$SMPROGRAMS\Artegame"

    ; Remove files and directories
    Delete "$INSTDIR\artegame.exe"
    Delete "$INSTDIR\Uninstall.exe"
    RMDir /r "$INSTDIR\assets"
    RMDir /r "$INSTDIR\src"

    ; Remove root install folder if empty
    RMDir "$INSTDIR"

    ; Remove registry keys
    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Artegame"
    DeleteRegKey HKCU "Software\Artegame"
SectionEnd
