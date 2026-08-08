#!/bin/bash

PORT=8080
DATA_DIR=/data
FLAG="$DATA_DIR/ui_capture_enabled"
PIDFILE="$DATA_DIR/ui_remote.pid"
LOGFILE="$DATA_DIR/ui_remote.log"
PAGE="$DATA_DIR/ui.html"
MAX_RUNTIME=10800   # 3 hours
WATCHDOG_PIDFILE="$DATA_DIR/ui_remote_watchdog.pid"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

start() {
  # Enable Qt screenshot capture
  touch "$FLAG"

  # Don't start another server if ours is already running
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Remote UI already running (PID $(cat "$PIDFILE"))"
  else
    cd "$DATA_DIR" || exit 1

    nohup python3 "$SCRIPT_DIR/ui_server.py" \
      > "$LOGFILE" 2>&1 &

    echo $! > "$PIDFILE"
    echo "Started remote UI server (PID $!)"
  fi

  IP=$(hostname -I | awk '{print $1}')

  echo
  echo "UI capture: ENABLED"
  echo "Viewer: http://${IP}:${PORT}/ui.html"

  # Auto-stop after MAX_RUNTIME seconds
  if [ -f "$WATCHDOG_PIDFILE" ]; then
    OLD_PID=$(cat "$WATCHDOG_PIDFILE")
    kill "$OLD_PID" 2>/dev/null || true
  fi

  (
    sleep "$MAX_RUNTIME"
    "$0" stop
  ) >/dev/null 2>&1 &

  echo $! > "$WATCHDOG_PIDFILE"

  # Stop remote capture automatically when the car goes on-road.
  (
    cd /data/openpilot || exit 1

    python3 - <<'PY'
  import time
  import subprocess
  import cereal.messaging as messaging

  sm = messaging.SubMaster(["deviceState"])

  while True:
    sm.update(1000)

    if sm.alive["deviceState"] and sm["deviceState"].started:
      subprocess.run(["/data/ui_remote.sh", "stop"])
      break

    time.sleep(1)
PY
  ) >/dev/null 2>&1 &
}

stop() {
  rm -f "$FLAG"

  if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")

    if kill -0 "$PID" 2>/dev/null; then
      kill "$PID"
      echo "Stopped remote UI server (PID $PID)"
    fi

    rm -f "$PIDFILE"
  fi

  echo "UI capture: DISABLED"

  if [ -f "$WATCHDOG_PIDFILE" ]; then
    WATCHDOG_PID=$(cat "$WATCHDOG_PIDFILE")

    # Don't kill ourselves if stop() was invoked by the watchdog.
    if [ "$WATCHDOG_PID" != "$$" ]; then
      kill "$WATCHDOG_PID" 2>/dev/null || true
    fi

    rm -f "$WATCHDOG_PIDFILE"
  fi
}

status() {
  if [ -f "$FLAG" ]; then
    echo "UI capture: ENABLED"
  else
    echo "UI capture: DISABLED"
  fi

  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Web server: RUNNING (PID $(cat "$PIDFILE"))"

    IP=$(hostname -I | awk '{print $1}')
    echo "Viewer: http://${IP}:${PORT}/ui.html"
  else
    echo "Web server: STOPPED"
  fi
}

case "${1:-start}" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    stop
    sleep 1
    start
    ;;
  status)
    status
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac
