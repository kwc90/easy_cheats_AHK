#Requires AutoHotkey v2.0
; === Hold ` (SC029), then hold Alt, then tap your macro's TRIGGER_KEY (from macros.ini) ===
; Backtick types normally; only the combo-time trigger key press is swallowed.

; ---------------- Master settings (stay here) ----------------
SEND_ENTER_AT_END := true          ; hit Enter after command
LIMIT_TO_EXE := "Game.exe"            ; e.g. "Game.exe" or "" for any window

; Timing (ms)
PRE_RELEASE_DELAY := 0
DOWN_DELAY := 0
UP_DELAY := 0
BETWEEN_KEYS := 0

; ---------------- Multi-macro INI ----------------
; Example macros.ini:
;   [noclip]
;   TRIGGER_KEY=n
;   COMMAND_STRING=noclip
;   Enabled=1
;
;   [god]
;   TRIGGER_KEY=g
;   COMMAND_STRING=god
;   Enabled=1
INI_PATH := A_ScriptDir "\cheat_macros.ini"

; Data
macros := []        ; [{name, key, cmd, enabled}]
triggerToIdx := Map()     ; "g" -> 1, "F8" -> 2, "SC031" -> 3

; Combo state
tickHeld := false   ; physical ` down
altSeenAfterTick := false   ; Alt pressed after `
isCapturing := false   ; currently listening for trigger?

; ---------------- Startup ----------------
LoadAllMacros()
BuildTriggerMap()
BuildTrayMenu()

; Quick helpers
^!l:: ReloadEverything()
^!r:: Reload()

ReloadEverything() {
    global
    LoadAllMacros()
    BuildTriggerMap()
    BuildTrayMenu()
    TrayTip("Macros", "Reloaded from macros.ini (" macros.Length " macro(s)).", 1500)
}

BuildTrayMenu() {
    global macros
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Reload Macros (Ctrl+Alt+L)", (*) => ReloadEverything())
    A_TrayMenu.Add("Full Reload (Ctrl+Alt+R)", (*) => Reload())
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

    ; Optional: enforce active EXE before we even listen
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
        ih.KeyOpt(IHKeyName(k), "ES")   ; mark as EndKey
    }

    ih.Start()
    ih.Wait()          ; wait for one key or timeout
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

; ---------------- INI parsing ----------------
LoadAllMacros() {
    global INI_PATH, macros
    macros := []
    if !FileExist(INI_PATH) {
        TrayTip("Macros", "No macros.ini found beside script.", 2500)
        return
    }
    sections := GetIniSections(INI_PATH)
    for name in sections {
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
; Normalize to: single letters => lowercase ("g"), Space => "Space",
; F-keys => "F8", scan codes => "SC031". Case-insensitive overall.
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

; InputHook.EndKey sometimes returns vk/sc forms; fold them back
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

; InputHook.KeyOpt wants a key name; accept our normalized set.
IHKeyName(k) {
    ; It already accepts "g", "Space", "F8", "SC031" (case-insensitive)
    return k
}
