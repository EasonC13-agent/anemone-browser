#!/bin/bash
# === Anemone Browser Healthcheck & Auto-Recovery ===
# Monitors Xvfb, fluxbox, x11vnc, websockify, Chrome.
# Restarts any crashed/defunct component without tearing down the whole stack.
#
# Usage:
#   bash healthcheck.sh [display_num] [vnc_port] [novnc_port] [cdp_port]
#   - Run manually, or install as cron (every 1-2 min)
#   - Logs to /tmp/anemone-healthcheck.log
#
# Install as cron:
#   echo "*/2 * * * * bash /root/healthcheck.sh 99 5900 6080 9222 >> /tmp/anemone-healthcheck.log 2>&1" | crontab -

DISPLAY_NUM="${1:-99}"
VNC_PORT="${2:-5900}"
NOVNC_PORT="${3:-6080}"
CDP_PORT="${4:-9222}"
export DISPLAY=":${DISPLAY_NUM}"

LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"
FIXED=0

log() { echo "${LOG_PREFIX} $1"; }

# --- 1. Check for defunct (zombie) processes and clean them ---
DEFUNCT_PIDS=$(ps aux | grep -E '(fluxbox|x11vnc|Xvfb|chrome|websockify)' | grep defunct | awk '{print $2}')
if [ -n "$DEFUNCT_PIDS" ]; then
  log "WARNING: Found defunct processes: $DEFUNCT_PIDS"
  for pid in $DEFUNCT_PIDS; do
    # Try to reap by killing parent, or just record
    PPID=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -n "$PPID" ] && [ "$PPID" != "1" ]; then
      log "  Sending SIGCHLD to parent $PPID of defunct $pid"
      kill -SIGCHLD "$PPID" 2>/dev/null
    fi
  done
  FIXED=1
fi

# --- 2. Xvfb ---
if ! pgrep -f "Xvfb :${DISPLAY_NUM}" > /dev/null 2>&1; then
  log "FIXING: Xvfb not running on :${DISPLAY_NUM}"
  # Clean stale lock
  rm -f "/tmp/.X${DISPLAY_NUM}-lock" "/tmp/.X11-unix/X${DISPLAY_NUM}"
  Xvfb ":${DISPLAY_NUM}" -screen 0 1920x1080x24 &
  sleep 2
  if pgrep -f "Xvfb :${DISPLAY_NUM}" > /dev/null; then
    log "  Xvfb restarted OK"
  else
    log "  ERROR: Xvfb failed to restart"
  fi
  FIXED=1
fi

# --- 3. Fluxbox ---
# Check for running AND non-defunct fluxbox
FLUXBOX_OK=$(pgrep -x fluxbox 2>/dev/null)
FLUXBOX_DEFUNCT=$(ps aux | grep fluxbox | grep defunct)
if [ -z "$FLUXBOX_OK" ] || [ -n "$FLUXBOX_DEFUNCT" ]; then
  log "FIXING: fluxbox not running or defunct"
  pkill -9 -x fluxbox 2>/dev/null
  sleep 1
  fluxbox &>/dev/null &
  sleep 2
  if pgrep -x fluxbox > /dev/null && ! ps aux | grep fluxbox | grep -q defunct; then
    log "  fluxbox restarted OK"
  else
    log "  ERROR: fluxbox still bad after restart"
  fi
  FIXED=1
fi

# --- 4. x11vnc ---
if ! pgrep -f "x11vnc.*:${DISPLAY_NUM}" > /dev/null 2>&1 || ps aux | grep x11vnc | grep -q defunct; then
  log "FIXING: x11vnc not running or defunct"
  pkill -9 -f x11vnc 2>/dev/null
  sleep 1
  x11vnc -display ":${DISPLAY_NUM}" -forever -shared -noshm \
    -rfbauth /root/.vnc/passwd \
    -rfbport "$VNC_PORT" \
    -bg -o /tmp/x11vnc.log
  sleep 1
  if pgrep -f x11vnc > /dev/null; then
    log "  x11vnc restarted OK"
  else
    log "  ERROR: x11vnc failed to restart. Log: $(tail -3 /tmp/x11vnc.log)"
  fi
  FIXED=1
fi

# --- 5. websockify (noVNC) ---
if ! pgrep -f "websockify.*${NOVNC_PORT}" > /dev/null 2>&1; then
  log "FIXING: websockify not running on port ${NOVNC_PORT}"
  websockify --web=/usr/share/novnc --cert=/root/.vnc/combined.pem \
    "$NOVNC_PORT" "localhost:${VNC_PORT}" &>/tmp/novnc.log &
  sleep 1
  if pgrep -f "websockify.*${NOVNC_PORT}" > /dev/null; then
    log "  websockify restarted OK"
  else
    log "  ERROR: websockify failed to restart"
  fi
  FIXED=1
fi

# --- 6. Chrome ---
if ! pgrep -f "chrome.*${CDP_PORT}" > /dev/null 2>&1; then
  log "FIXING: Chrome not running (CDP port ${CDP_PORT})"
  google-chrome-stable \
    --no-sandbox \
    --disable-gpu \
    --disable-dev-shm-usage \
    --disable-blink-features=AutomationControlled \
    --user-data-dir=/root/.chrome-profile \
    --remote-debugging-port="$CDP_PORT" \
    --remote-debugging-address=127.0.0.1 \
    --display=":${DISPLAY_NUM}" \
    --window-size=1920,1080 \
    --start-maximized \
    &>/dev/null &
  sleep 4
  if pgrep -f "chrome.*${CDP_PORT}" > /dev/null; then
    log "  Chrome restarted OK"
  else
    log "  ERROR: Chrome failed to restart"
  fi
  FIXED=1
fi

# --- Summary ---
if [ $FIXED -eq 0 ]; then
  log "OK: All services healthy"
else
  log "DONE: Applied fixes (see above)"
fi
