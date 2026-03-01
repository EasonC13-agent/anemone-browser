# docker-vnc-browser

Headful Chrome + noVNC for Docker containers. Gives AI agents a real browser with human intervention capability.

## Problem

Headless Chrome in Docker gets blocked by Google, Cloudflare, and other anti-bot systems due to:
- `HeadlessChrome` in User-Agent string
- `navigator.webdriver = true`
- Missing GPU/font/plugin fingerprints

## Solution

This skill runs Chrome in **headful mode** inside a virtual display (Xvfb), providing:

- **Anti-detection**: Real Chrome rendering, no headless fingerprints
- **Human VNC access**: Web-based noVNC with SSL + password for manual intervention
- **Agent CDP access**: Chrome DevTools Protocol for automation
- **Persistent profile**: Cookies and sessions survive restarts
- **Secure**: SSL encryption, password protection, localhost-only VNC

## Quick Start

```bash
# 1. Install dependencies (once per container)
docker cp setup-vnc-browser.sh mycontainer:/tmp/
docker cp start_vnc_browser.sh mycontainer:/tmp/
docker exec mycontainer bash /tmp/setup-vnc-browser.sh

# 2. Start environment
docker exec mycontainer bash /root/start_vnc_browser.sh
# Output: URL with auto-generated 14-char password

# 3. Access via browser
# https://<IP>:6080/vnc.html?password=<PASS>&autoconnect=true&resize=scale
```

## Customization

```bash
# Custom password + ports + resolution
bash /root/start_vnc_browser.sh "mypassword" 6080 9222 1920x1080x24

# Arguments:
#   $1 - Password (default: random 14-char)
#   $2 - noVNC port (default: 6080)
#   $3 - CDP port (default: 9222)
#   $4 - Resolution (default: 1920x1080x24)
```

## Architecture

```
User Browser ──(HTTPS/WSS)──> websockify:6080 ──(localhost)──> x11vnc:5900
                                                                    │
                                                              Xvfb :99 (virtual display)
                                                                    │
                                                              Chrome (headful, kiosk)
                                                                    │
AI Agent ──────(CDP)──────────────────────────────────────> Chrome:9222
```

## Tested Environments

| Server | IP Type | Google Search | Google Scholar |
|--------|---------|--------------|----------------|
| liquidlink-server (home) | Residential | ✅ | ✅ |
| OVH (France) | Datacenter | ✅ | ✅ |

## Files

| File | Purpose |
|------|---------|
| `setup-vnc-browser.sh` | One-time dependency installation |
| `start_vnc_browser.sh` | Start environment (idempotent, safe to re-run) |
| `test_browser.py` | Test Google/Scholar access via CDP |
| `SKILL.md` | Agent instructions for OpenClaw |
| `README.md` | This file |

## Security Notes

- Password is random 14-char alphanumeric by default
- SSL via self-signed certificate (auto-generated)
- x11vnc listens on localhost only
- All external traffic goes through websockify SSL proxy
- Chrome profile persisted at `/root/.chrome-profile`

## License

MIT
