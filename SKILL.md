# Docker VNC Browser Skill

Headful Chrome + noVNC for Docker/Linux containers. Provides anti-detection browsing with both CDP automation and human VNC intervention.

## When to Use

- You need a browser inside a Docker/Linux container
- Headless Chrome is getting blocked by Google, Cloudflare, etc.
- You need human intervention capability (login, CAPTCHA solving)
- You're on a VPS/server without a desktop environment

## Setup (One-Time)

Copy both scripts into the container and run setup:

```bash
# From host
docker cp setup-vnc-browser.sh <container>:/tmp/
docker cp start_vnc_browser.sh <container>:/tmp/
docker exec <container> bash /tmp/setup-vnc-browser.sh
```

Or from inside the container:
```bash
bash /path/to/setup-vnc-browser.sh
```

This installs: Google Chrome, Xvfb, x11vnc, noVNC, fluxbox, websockify, openssl.

## Start Environment

```bash
# Random password, default ports (noVNC: 6080, CDP: 9222)
bash /root/start_vnc_browser.sh

# Custom password
bash /root/start_vnc_browser.sh "mypassword"

# Custom password + ports
bash /root/start_vnc_browser.sh "mypassword" 6080 9222

# Custom resolution (4th arg)
bash /root/start_vnc_browser.sh "" 6080 9222 1920x1080x24
```

Output includes the full noVNC URL with password embedded.

## Human Access (noVNC)

```
https://<IP>:<NOVNC_PORT>/vnc.html?password=<PASS>&autoconnect=true&resize=scale
```

- Self-signed SSL cert (browser will warn, click through)
- `resize=scale` auto-fits to browser window
- Chrome runs in kiosk mode (fullscreen, no window decorations)

## Agent Access (CDP)

The Chrome instance exposes CDP. To use from OpenClaw:

### Option 1: OpenClaw browser config (recommended)

Add to the container's OpenClaw config (`~/.openclaw/openclaw.json`):
```json
{
  "browser": {
    "headless": false,
    "noSandbox": true,
    "executablePath": "/usr/bin/google-chrome-stable"
  }
}
```

Then use `browser action=snapshot profile=openclaw` etc. normally.

### Option 2: Direct CDP via Python

```python
import json, urllib.request
version = json.loads(urllib.request.urlopen("http://127.0.0.1:<CDP_PORT>/json/version").read())
ws_url = version["webSocketDebuggerUrl"]
# Connect via websockets and send CDP commands
```

### Important: Override User-Agent

Always override the UA via CDP before visiting Google/Scholar:
```python
# Via CDP websocket
{"method": "Network.setUserAgentOverride", "params": {
  "userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.7632.116 Safari/537.36"
}}
```

This removes "HeadlessChrome" from the UA string, which is the main detection vector.

## Testing

```bash
python3 test_browser.py <CDP_PORT>
```

Tests Google Search and Google Scholar access. Both should return "OK".

## Ports

| Service | Default | Purpose |
|---------|---------|---------|
| noVNC | 6080 | Human web access (SSL) |
| x11vnc | 5900 | Internal VNC (localhost only) |
| Chrome CDP | 9222 | Agent automation |

Ensure these ports are mapped in your Docker container.

## Security

- VNC password: random 14-char alphanumeric by default
- SSL: self-signed cert, auto-generated on first run
- x11vnc: localhost-only binding
- External access only through websockify SSL proxy

## Anti-Detection Features

- Headful Chrome (not headless) via Xvfb virtual display
- `--disable-blink-features=AutomationControlled` (hides navigator.webdriver)
- Persistent Chrome profile at `/root/.chrome-profile` (cookies survive restarts)
- Kiosk mode (fullscreen, realistic window dimensions)
- Human can intervene via VNC to solve CAPTCHAs and login

## Files

| File | Location | Purpose |
|------|----------|---------|
| `setup-vnc-browser.sh` | Run once | Installs all dependencies |
| `start_vnc_browser.sh` | `/root/` after setup | Starts environment (idempotent) |
| `test_browser.py` | Optional | Tests Google/Scholar access |
