#!/bin/bash

PORT=8080
DATA_DIR=/data

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/ui_remote.sh"

FLAG="$DATA_DIR/ui_capture_enabled"
PIDFILE="$DATA_DIR/ui_remote.pid"
LOGFILE="$DATA_DIR/ui_remote.log"

TIMEOUT_PIDFILE="$DATA_DIR/ui_remote_timeout.pid"
ROAD_PIDFILE="$DATA_DIR/ui_remote_road.pid"

MAX_RUNTIME=10800   # 3 hours


get_ip() {
  IP=$(ip -4 -o addr show dev wlan0 2>/dev/null | awk '{print $4}' | cut -d/ -f1)

  if [ -z "$IP" ]; then
    IP=$(hostname -I | awk '{print $1}')
  fi

  echo "$IP"
}


start() {
  touch "$FLAG"

  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Remote UI already running (PID $(cat "$PIDFILE"))"
  else
    pkill -f "$SCRIPT_DIR/ui_server.py" 2>/dev/null || true
    pkill -f 'http.server 8080' 2>/dev/null || true
    nohup python3 "$SCRIPT_DIR/ui_server.py" \
      >"$LOGFILE" 2>&1 &

    echo $! > "$PIDFILE"
    echo "Started remote UI server (PID $!)"
  fi

  # Kill any old timeout watchdog.
  if [ -f "$TIMEOUT_PIDFILE" ]; then
    kill "$(cat "$TIMEOUT_PIDFILE")" 2>/dev/null || true
    rm -f "$TIMEOUT_PIDFILE"
  fi

  # Hard timeout.
  (
    sleep "$MAX_RUNTIME"
    "$SCRIPT_PATH" stop
  ) >/dev/null 2>&1 &

  echo $! > "$TIMEOUT_PIDFILE"

  # Kill any old on-road watchdog.
  if [ -f "$ROAD_PIDFILE" ]; then
    kill "$(cat "$ROAD_PIDFILE")" 2>/dev/null || true
    rm -f "$ROAD_PIDFILE"
  fi

  # Stop capture automatically when the car goes on-road.
  REMOTE_SCRIPT="$SCRIPT_PATH" \
  PYTHONPATH=/data/openpilot \
  nohup python3 - <<'PY' >/dev/null 2>&1 &
import os
import time
import subprocess
import cereal.messaging as messaging

remote_script = os.environ["REMOTE_SCRIPT"]
sm = messaging.SubMaster(["deviceState"])

while True:
  sm.update(1000)

  if sm.alive["deviceState"] and sm["deviceState"].started:
    subprocess.Popen(["bash", remote_script, "stop"])
    break

  time.sleep(1)
PY

  echo $! > "$ROAD_PIDFILE"

  IP=$(get_ip)

  echo
  echo "UI capture: ENABLED"
  echo "Viewer: http://${IP}:${PORT}/ui.html"
}


stop() {
  rm -f "$FLAG"
  rm -f "$DATA_DIR/ui_remote_click"
  rm -f "$DATA_DIR/ui_remote_click.tmp"

  if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")

    if kill -0 "$PID" 2>/dev/null; then
      kill "$PID" 2>/dev/null || true
      echo "Stopped remote UI server (PID $PID)"
    fi

    rm -f "$PIDFILE"
  fi

  if [ -f "$TIMEOUT_PIDFILE" ]; then
    PID=$(cat "$TIMEOUT_PIDFILE")

    if [ "$PID" != "$$" ]; then
      kill "$PID" 2>/dev/null || true
    fi

    rm -f "$TIMEOUT_PIDFILE"
  fi

  if [ -f "$ROAD_PIDFILE" ]; then
    PID=$(cat "$ROAD_PIDFILE")

    if [ "$PID" != "$$" ]; then
      kill "$PID" 2>/dev/null || true
    fi

    rm -f "$ROAD_PIDFILE"
  fi

  echo "UI capture: DISABLED"
}


status() {
  if [ -f "$FLAG" ]; then
    echo "UI capture: ENABLED"
  else
    echo "UI capture: DISABLED"
  fi

  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Web server: RUNNING (PID $(cat "$PIDFILE"))"

    IP=$(get_ip)
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