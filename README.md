# Easy Cheats (AHK v2)

Gross little LLM-generated AutoHotkey v2 helper that fires in-game console commands with a quick gesture to EFPSE.  

**Gesture:** 
1. Hold **~** + **Alt**
2. Tap a **hotkey** (like g for godmode)
   * Now it will type godmode in the console and hit enter for you! (you can turn this off if you want)
   
---

>This ahk script is a workaround to the fact that you cannot bind console cheats to key in EFPSCE (that I'm aware of)
>
>Clark does amazing work and honestly I wouldn't expect him to add this feature at all,
>I hope this hacky tool will be useful enough that he doesn't have to bother. :)
>
>Please consider dropping Clark some bucks if you got them, EFPSCE is lots of fun and he does this all for free:
>
>https://www.patreon.com/ClarksDen

---

## Files

- **`Easy_Cheats.ahk`** – main script (logic, some tunable params)
- **`cheat_macros.ini`** – user-editable macros (keys → text).

> Requires **AutoHotkey v2** (not v1).

---

## Setup

1. Install **AutoHotkey v2**.
2. Put `cheat_hotkeys.ahk` and `cheat_macros.ini` in the **same folder**.
3. Double-click `cheat_hotkeys.ahk` (tray icon appears).
4. In the game: **hold `**, **hold Alt**, **tap a trigger key**.

**Quick controls**
- Reload macros (re-read INI): **Ctrl+Alt+L** (off by default)
- Full reload script: **Ctrl+Alt+R** (off by default)


---

## Editing `cheat_macros.ini`

Each section defines one macro:

```ini
[macro_name]
TRIGGER_KEY=g          ; a–z, F1–F12, Space, or SC### scan code
COMMAND_STRING=god     ; what gets typed
Enabled=1              ; 1 = on, 0 = off
```

You can add more of these, change their trigger key, enable or disable them.

> After edits, go to the system tray and reload the script, or use the optional hotkey.

**Valid `TRIGGER_KEY` values**

- Letters: `a`..`z` (case-insensitive; script normalizes to lowercase)  
- Function keys: `F1`..`F12`  
- Special: `Space`  

---

## Script settings (in `cheat_hotkeys.ahk`)

Can change this if you dont want easy keys to press enter automatically:
```ahk
SEND_ENTER_AT_END := true
```

This locks easy cheats to only work when you have the game running, editable if you need it:
```ahk
LIMIT_TO_EXE      := "Game.exe"
```

Typing timings (ms). Raise if letters drop; lower for speed. You may want to turn these up if you're noticing too many issues.
```ahk
PRE_RELEASE_DELAY := 1
DOWN_DELAY        := 1
UP_DELAY          := 1
BETWEEN_KEYS      := 1
```

---

## Known limitations & bugs

1) **Typing seems slow**  
   - The script sends true key down/up per character for compatibility, I couldn't get it to be any faster without dropping characters too much
  
2) **Commands add characters like "CTRL" or enter out too quickly
   - Haven't figured this one out yet myself, although I find if you do the ~ + alt chord and then just tap your trigger key and release them all, it's more consistent.

4) **Single-key triggers only**  
   - Capture listens for one key (letters, F-keys, Space).

5) **Duplicate triggers**  
   - If two sections share the same `TRIGGER_KEY`, only one wins. Make them unique.

6) **Special characters in `COMMAND_STRING`**  
   - Unfortunately can't figure this out. if you're trying to send a console one-liner, you'll need to pres ; and press space before sending the command, no ; ( ) /= etc in the COMMAND_STRING. :(


---

## Troubleshooting

- **Macro did nothing**
  - Use **AutoHotkey v2**.
  - Ensure `[section]` has `Enabled=1`.
  - Make sure you have `LIMIT_TO_EXE := "Game.exe"` if you only want it running in Game, or turn it off to see if it works at all.

- **Letters drop / out of order**
  - Increase timing (e.g., set delays to `2–8` ms).  
  - EFPSCE may just need that time to register the keys, but it's likely a bug on my end, sorry!


---

## Safety

This sends ordinary keystrokes, but some games/services **forbid** automation. This ahk script was made to help with EFPSE development *only*, so don't use this for other stuff lest you may get banned from a game or something.

