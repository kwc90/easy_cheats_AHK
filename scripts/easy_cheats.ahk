#Requires AutoHotkey v2.0
; === Hold ` (SC029), then hold Alt, then tap a trigger key from cheat_macros.ini => sends its COMMAND_STRING ===
; Backtick types normally; only the combo-time trigger key press is swallowed.

; ---------------- Master settings (stay here) ----------------
SEND_ENTER_AT_END := true          ; hit Enter after command
LIMIT_TO_EXE := "Game.exe"            ; e.g. "Game.exe" or "" for any window

; Timing (ms)
PRE_RELEASE_DELAY := 1
DOWN_DELAY := 1
UP_DELAY := 1
BETWEEN_KEYS := 1

; ---------------- Paths ----------------
INI_PATH := A_ScriptDir "\cheat_macros.ini"

; ---------------- Data ----------------
macros := []        ; [{name, key, cmd, enabled}]
triggerToIdx := Map()     ; "g" -> index, "F8" -> index, "SC031" -> index

; Settings persisted to INI->[settings]
ENABLE_RELOAD_HK := 0   ; Ctrl+Alt+L
ENABLE_FULLRELOAD_HK := 0   ; Ctrl+Alt+R

; Combo state
tickHeld := false   ; physical ` down
altSeenAfterTick := false   ; Alt pressed after `
isCapturing := false   ; listening for trigger?

; ---------------- Startup ----------------
LoadSettings()
LoadAllMacros()
BuildTriggerMap()
ApplyManagementHotkeys()
BuildTrayMenu()
ShowLoadedToast()  ; <— toast confirms macros loaded

; ---------------- Management hotkeys (registered dynamically) ----------------
ReloadEverything(*) {
    global
    LoadAllMacros()
    BuildTriggerMap()
    BuildTrayMenu()
    ShowLoadedToast()  ; <— toast on reload too
}
FullReload(*) {
    Reload()
}

ApplyManagementHotkeys() {
    global ENABLE_RELOAD_HK, ENABLE_FULLRELOAD_HK
    ; Turn both off first (in case names already registered)
    try Hotkey("^!l", "Off")
    try Hotkey("^!r", "Off")

    if ENABLE_RELOAD_HK {
        try Hotkey("^!l", "ReloadEverything", "On")
    }
    if ENABLE_FULLRELOAD_HK {
        try Hotkey("^!r", "FullReload", "On")
    }
}

; ---------------- Tray menu ----------------
BuildTrayMenu() {
    global macros, ENABLE_RELOAD_HK, ENABLE_FULLRELOAD_HK

    A_TrayMenu.Delete()
    A_TrayMenu.Add("Reload Macros (Ctrl+Alt+L)", (*) => ReloadEverything())
    if !ENABLE_RELOAD_HK {
        A_TrayMenu.Add("— Reload hotkey disabled —", (*) => 0)
        A_TrayMenu.Disable("— Reload hotkey disabled —")
    }
    A_TrayMenu.Add("Full Reload (Ctrl+Alt+R)", (*) => FullReload())
    if !ENABLE_FULLRELOAD_HK {
        A_TrayMenu.Add("— Full reload hotkey disabled —", (*) => 0)
        A_TrayMenu.Disable("— Full reload hotkey disabled —")
    }

    ; New: open the INI in Notepad
    A_TrayMenu.Add()
    A_TrayMenu.Add("Open cheat_macros.ini", (*) => OpenIniInNotepad())

    A_TrayMenu.Add() ; separator

    ; Options submenu (checkable)
    opts := Menu()
    item1 := "Enable Reload Hotkey (Ctrl+Alt+L)"
    item2 := "Enable Full Reload Hotkey (Ctrl+Alt+R)"
    opts.Add(item1, ToggleReloadHotkey)
    opts.Add(item2, ToggleFullReloadHotkey)
    if ENABLE_RELOAD_HK
        opts.Check(item1)
    else
        opts.Uncheck(item1)
    if ENABLE_FULLRELOAD_HK
        opts.Check(item2)
    else
        opts.Uncheck(item2)
    A_TrayMenu.Add("Options", opts)

    ; Active macros (read-only)
    A_TrayMenu.Add()
    if (macros.Length) {
        header := "Active Macros:"
        A_TrayMenu.Add(header, (*) => 0), A_TrayMenu.Disable(header)
        for m in macros {
            label := (m.enabled ? "✔ " : "✖ ") m.name "  [" m.key " → " m.cmd "]"
            A_TrayMenu.Add(label, (*) => 0), A_TrayMenu.Disable(label)
        }
    } else {
        none := "(no macros found)"
        A_TrayMenu.Add(none, (*) => 0), A_TrayMenu.Disable(none)
    }

    ; Exit
    A_TrayMenu.Add()
    A_TrayMenu.Add("Exit Cheat Hotkeys", (*) => ExitApp())
}

; --- New helpers for INI editing ---
EnsureIniExists() {
    global INI_PATH
    if !FileExist(INI_PATH) {
        template :=
            (
                "[settings]`r`n"
                "EnableReloadHotkey=1`r`n"
                "EnableFullReloadHotkey=1`r`n"
                "`r`n"
                "; Example macro section:`r`n"
                "; [noclip]`r`n"
                "; TRIGGER_KEY=n`r`n"
                "; COMMAND_STRING=noclip`r`n"
                "; Enabled=1`r`n"
            )
        FileAppend(template, INI_PATH, "UTF-8")
    }
}

OpenIniInNotepad(*) {
    global INI_PATH
    EnsureIniExists()
    try Run('notepad.exe "' INI_PATH '"')
}

ToggleReloadHotkey(*) {
    global ENABLE_RELOAD_HK
    ENABLE_RELOAD_HK := !ENABLE_RELOAD_HK
    SaveSettings()
    ApplyManagementHotkeys()
    BuildTrayMenu()
    ShowLoadedToast()
}

ToggleFullReloadHotkey(*) {
    global ENABLE_FULLRELOAD_HK
    ENABLE_FULLRELOAD_HK := !ENABLE_FULLRELOAD_HK
    SaveSettings()
    ApplyManagementHotkeys()
    BuildTrayMenu()
    ShowLoadedToast()
}

; ---------------- Backtick passthrough & Alt tracking ----------------
~*SC029:: {                    ; physical `
    global tickHeld, altSeenAfterTick
    tickHeld := true
    altSeenAfterTick := false
}
~*SC029 up:: {
    global tickHeld, altSeenAfterTick
    tickHeld := false
    altSeenAfterTick := false
}
~*Alt:: {
    global tickHeld, altSeenAfterTick
    if tickHeld {
        altSeenAfterTick := true
        TryStartCapture()          ; begin listening for trigger key
    }
}
~*Alt up:: {
    global altSeenAfterTick
    altSeenAfterTick := false
}

; ---------------- Combo + capture ----------------
TryStartCapture() {
    global isCapturing
    if isCapturing
        return
    isCapturing := true
    CaptureTriggerKey()
    isCapturing := false
}

CaptureTriggerKey() {
    global tickHeld, altSeenAfterTick, LIMIT_TO_EXE, macros, triggerToIdx

    if !ComboActive()
        return

    ; Enforce active EXE before we even listen (optional)
    if (LIMIT_TO_EXE != "" && !WinActive("ahk_exe " LIMIT_TO_EXE))
        return

    ; Build an InputHook that ends on any configured trigger
    ih := InputHook("L1 T3") ; capture exactly 1 key, 3s timeout
    for m in macros {
        if !m.enabled
            continue
        k := NormalizeKey(m.key)
        if (k = "")
            continue
        ; ES = End + Suppress so the trigger key itself doesn't leak
        ih.KeyOpt(IHKeyName(k), "ES")
    }
    ; Optional: allow Esc to cancel capture (no macro fired)
    ih.KeyOpt("Escape", "E")

    ih.Start()
    ih.Wait()                  ; wait for one key or timeout

    altSeenAfterTick := false  ; require re-entering the sequence next time

    if (ih.EndReason != "EndKey")
        return  ; timed out or canceled

    pressed := NormalizeKey(CanonicalizeEndKey(ih.EndKey))
    if !triggerToIdx.Has(pressed)
        return

    FireMacro(triggerToIdx[pressed])
}

ComboActive() {
    global tickHeld, altSeenAfterTick, LIMIT_TO_EXE
    if !(tickHeld && GetKeyState("Alt", "P") && altSeenAfterTick)
        return false
    if (LIMIT_TO_EXE != "" && !WinActive("ahk_exe " LIMIT_TO_EXE))
        return false
    return true
}

; ---------------- Fire macro ----------------
FireMacro(idx) {
    global macros, PRE_RELEASE_DELAY, DOWN_DELAY, UP_DELAY, BETWEEN_KEYS, SEND_ENTER_AT_END
    if (idx < 1 || idx > macros.Length)
        return
    m := macros[idx]
    if !m.enabled
        return

    Critical "On"
    Send("{Alt up}")
    Sleep(PRE_RELEASE_DELAY)

    SendCommand(m.cmd, DOWN_DELAY, UP_DELAY, BETWEEN_KEYS)

    if SEND_ENTER_AT_END {
        SendEvent("{Enter down}")
        Sleep(DOWN_DELAY)
        SendEvent("{Enter up}")
        Sleep(UP_DELAY)
    }
}

; ---------------- Send helper ----------------
SendCommand(cmd, downDelay := 5, upDelay := 5, between := 5) {
    for ch in StrSplit(cmd) {
        if (ch ~= "^[a-z]$") {
            SendEvent("{" ch " down}")
            Sleep(downDelay)
            SendEvent("{" ch " up}")
        } else if (ch ~= "^[A-Z]$") {
            lower := StrLower(ch)
            SendEvent("{Shift down}{" lower " down}")
            Sleep(downDelay)
            SendEvent("{" lower " up}{Shift up}")
        } else if (ch ~= "^[0-9]$") {
            SendEvent("{" ch " down}")
            Sleep(downDelay)
            SendEvent("{" ch " up}")
        } else if (ch = " ") {
            SendEvent("{Space down}")
            Sleep(downDelay)
            SendEvent("{Space up}")
        } else {
            Send(ch) ; punctuation/symbols etc.
        }
        Sleep(upDelay)
        Sleep(between)
    }
}

; ---------------- Toast helpers ----------------
CountEnabledMacros() {
    global macros
    c := 0
    for m in macros
        if m.enabled
            c++
    return c
}

ShowLoadedToast() {
    global macros
    total := macros.Length
    enabled := CountEnabledMacros()
    ; Build a short preview: up to 4 enabled macros as "key -> name"
    preview := ""
    shown := 0
    for m in macros {
        if !m.enabled
            continue
        preview .= (preview ? "`n" : "") m.key " → " m.name
        shown++
        if (shown >= 4)
            break
    }
    msg := "Loaded " enabled " of " total " macro(s)."
    TrayTip("Easy Cheats", msg, 1800)
}

; ---------------- INI: settings + macros ----------------
LoadSettings() {
    global INI_PATH, ENABLE_RELOAD_HK, ENABLE_FULLRELOAD_HK
    if !FileExist(INI_PATH) {
        return
    }
    ENABLE_RELOAD_HK := IniRead(INI_PATH, "settings", "EnableReloadHotkey", "1") = "1"
    ENABLE_FULLRELOAD_HK := IniRead(INI_PATH, "settings", "EnableFullReloadHotkey", "1") = "1"
}

SaveSettings() {
    global INI_PATH, ENABLE_RELOAD_HK, ENABLE_FULLRELOAD_HK
    IniWrite(ENABLE_RELOAD_HK ? "1" : "0", INI_PATH, "settings", "EnableReloadHotkey")
    IniWrite(ENABLE_FULLRELOAD_HK ? "1" : "0", INI_PATH, "settings", "EnableFullReloadHotkey")
}

LoadAllMacros() {
    global INI_PATH, macros
    macros := []
    if !FileExist(INI_PATH) {
        TrayTip("Cheat Hotkeys", "No cheat_macros.ini found beside script.", 2500)
        return
    }
    sections := GetIniSections(INI_PATH)
    for name in sections {
        if (StrLower(name) = "settings")
            continue
        key := Trim(IniRead(INI_PATH, name, "TRIGGER_KEY", ""))
        cmd := IniRead(INI_PATH, name, "COMMAND_STRING", "")
        en := Trim(IniRead(INI_PATH, name, "Enabled", "1"))
        enabled := (StrLower(en) != "0" && StrLower(en) != "false")
        macros.Push({ name: name, key: key, cmd: cmd, enabled: enabled })
    }
}

GetIniSections(path) {
    text := FileRead(path, "UTF-8")
    sections := []
    pos := 1
    while RegExMatch(text, "m)^\s*\[([^\]\r\n]+)\]\s*$", &m, pos) {
        sections.Push(Trim(m[1]))
        pos := m.Pos + m.Len
    }
    return sections
}

; Build trigger map from normalized key -> index
BuildTriggerMap() {
    global macros, triggerToIdx
    triggerToIdx := Map()
    for idx, m in macros {
        if !m.enabled
            continue
        k := NormalizeKey(m.key)
        if (k = "")
            continue
        triggerToIdx[k] := idx
    }
}

; ---------------- Key normalization helpers ----------------
NormalizeKey(k) {
    k := Trim(k)
    if (k = "")
        return ""
    if RegExMatch(k, "i)^SC\d{3}$")
        return "SC" SubStr(k, 3)   ; ensure uppercase SC
    if RegExMatch(k, "i)^F\d{1,2}$")
        return "F" SubStr(k, 2)    ; ensure uppercase F
    if (StrLower(k) = "space")
        return "Space"
    if (StrLen(k) = 1)
        return StrLower(k)         ; letters: "g"
    return k
}

CanonicalizeEndKey(k) {
    k := Trim(k)
    if (k = "")
        return ""
    ; Normalize "vkXXscYYY" -> "SCYYY" if SC present
    if RegExMatch(k, "i)sc(\d{3})", &m)
        return "SC" m[1]
    ; keep standard names as-is
    return k
}

IHKeyName(k) {
    ; Accept "g", "Space", "F8", "SC031"
    return k
}
