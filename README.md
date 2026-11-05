# qolhud

you need three values: client id, client secret and refresh token. it takes about five minutes and you only do it once.

## what you need

- a spotify account (premium is only needed for the play, pause and skip keys, showing the song works on free)
- a roblox executor with `request` or `http_request`
- for the album cover: `writefile` and `getcustomasset` (optional, the hud works without it)
- windows powershell, cmd, or any terminal with curl

## 1. create a spotify app

1. go to https://developer.spotify.com/dashboard and log in
2. click create app
3. type any name and description
4. in redirect uri, type exactly this and click add:

```
http://127.0.0.1:8888/callback
```

5. under which apis are you planning to use, tick web api
6. accept the terms and save
7. open the app and go to settings
8. copy the client id
9. click view client secret and copy it

## 2. get the authorization code

copy this link, replace `your_client_id` with your client id, and open it in your browser:

```
https://accounts.spotify.com/authorize?client_id=your_client_id&response_type=code&redirect_uri=http%3A%2F%2F127.0.0.1%3A8888%2Fcallback&scope=user-read-currently-playing%20user-read-playback-state%20user-modify-playback-state
```

click agree. the page will fail to load, that is normal. look at the address bar, it will look like this:

```
http://127.0.0.1:8888/callback?code=abc123...
```

copy everything after `code=`. this code expires in a few minutes and only works once, so do the next step right away.

## 3. get the refresh token

run this in a terminal. replace the three values with yours.

windows powershell or cmd (use `curl.exe`, plain `curl` in powershell is a different command and will fail):

```
curl.exe -X POST https://accounts.spotify.com/api/token -u "your_client_id:your_client_secret" -d grant_type=authorization_code -d "code=your_code" -d redirect_uri=http://127.0.0.1:8888/callback
```

mac or linux:

```
curl -X POST https://accounts.spotify.com/api/token -u "your_client_id:your_client_secret" -d grant_type=authorization_code -d "code=your_code" -d redirect_uri=http://127.0.0.1:8888/callback
```

the answer is a json. copy the value of `refresh_token`. it does not expire, the script renews the access token by itself.

## 4. fill the script

open the script and paste your values at the top:

```lua
CLIENT_ID     = "your_client_id",
CLIENT_SECRET = "your_client_secret",
REFRESH_TOKEN = "your_refresh_token",
```

if you leave them empty the hud still shows ping and fps, just without spotify.

## 5. run it

paste the script in your executor and execute. or save it in your executor's `workspace` folder and run this line, so you can edit the file and run it again without pasting:

```lua
loadstring(readfile("qol_hud_v2.lua"))()
```

## controls

- `f6` or click the selector: change theme (min, simple, gs)
- `f7` or click the art button: show or hide the album cover
- `rightcontrol`: hide or show the hud
- `[` previous song
- `]` next song
- `\` play or pause

you can drag the hud by the panel, the text or the progress bar. position, theme and cover setting are saved in `QOLHudSettings.json`. every key can be changed in the config table at the top of the script.

## unloading and updating

running the script again removes the old one and loads the new one, you do not need to rejoin the game. to remove the hud without loading anything:

```lua
getgenv().QOL_HUD()
```

## troubleshooting

- `invalid_grant`: the code expired, was already used, or the redirect uri does not match. repeat step 2 and 3 quickly
- `invalid_client`: the client id or client secret is wrong
- hud says nothing playing: start a song in the spotify app on any device and wait a few seconds
- skip and pause do nothing: those need spotify premium
- no album cover: your executor is missing `writefile` or `getcustomasset`, or the cover is turned off with `f7`
- the hud is stuck in a weird place: delete `QOLHudSettings.json` from your executor's `workspace` folder and run it again

## security

- never post or share the script with your client secret or refresh token filled in. if you put the project on github, keep the filled version out of the repo
- if you leak them by mistake, rotate the client secret in the spotify dashboard and remove the app's access at https://www.spotify.com/account/apps, then redo this guide
