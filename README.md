# Picker
*The reason why I am not gonna test this in actual multiplayer server...*

<img src="https://github.com/user-attachments/assets/91968a32-1602-4d92-97b5-cdcfbcbf595c" alt="whoa the picker?!" width="600">

Replicated server-side aimbot from Interloper F for cs:s using vscript tho this will work on source games that are on tf2 branch or something lol
it also includes sourcemod plugin as well which I think it will work on source games that supports sourcemod? Maybe... lol

## Installation

### VScript Installation
1. place `picker.nut` in `cstrike/scripts/vscripts/`
2. open your game (cs:s or hl2dm or etc), create a server
3. in console: `script_execute picker.nut`

### SourceMod Plugin Installation
1. place `picker.smx` in `cstrike/addons/sourcemod/plugins/`
2. restart your server or load the plugin with `sm plugins load picker` in console
3. the plugin will automatically load on server start

## Usage

### Console commands for VScript
```
picker_toggle - turn on/off 
picker_next - cycle through targets manually
```

### Console commands for VScript
```
sm_giveaimbot - give aimbot to someone (why tho)
sm_aimbot_distance - max distance for aimbot
sm_aimbot_smoothing - smoothing amount
```

### Chat commands for SourceMod
```
!aimbot or /aimbot or !picker or /picker - toggle on/off
!nexttarget or /nexttarget - cycle through targets manually
```
  
you can bind them and that's basically it! have fun!
