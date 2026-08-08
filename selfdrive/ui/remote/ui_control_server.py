#!/usr/bin/env python3

import os
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = 8081

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REMOTE_SCRIPT = os.path.join(SCRIPT_DIR, "ui_remote.sh")


def run_remote(command):
  return subprocess.run(
    ["bash", REMOTE_SCRIPT, command],
    capture_output=True,
    text=True,
  )


class Handler(BaseHTTPRequestHandler):
  def do_GET(self):
    host = self.headers.get("Host", "localhost").split(":")[0]

    if self.path == "/start":
      result = run_remote("start")

      if result.returncode != 0:
        self.send_response(500)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write((result.stdout + result.stderr).encode())
        return

      self.send_response(302)
      self.send_header("Location", f"http://{host}:8080/ui.html")
      self.end_headers()
      return

    if self.path == "/stop":
      result = run_remote("stop")

      self.send_response(200 if result.returncode == 0 else 500)
      self.send_header("Content-Type", "text/plain")
      self.end_headers()
      self.wfile.write((result.stdout + result.stderr).encode())
      return

    if self.path == "/status":
      result = run_remote("status")

      self.send_response(200 if result.returncode == 0 else 500)
      self.send_header("Content-Type", "text/plain")
      self.end_headers()
      self.wfile.write((result.stdout + result.stderr).encode())
      return

    self.send_response(200)
    self.send_header("Content-Type", "text/html")
    self.end_headers()

    self.wfile.write(b"""
<!doctype html>
<html>
<head>
  <title>Comma Remote UI</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body {
      background: #111;
      color: white;
      font-family: sans-serif;
      text-align: center;
      padding-top: 100px;
    }

    a {
      display: inline-block;
      margin: 20px;
      padding: 25px 45px;
      background: #333;
      color: white;
      text-decoration: none;
      border-radius: 12px;
      font-size: 30px;
    }
  </style>
</head>
<body>
  <h1>Comma Remote UI</h1>
  <a href="/start">Start</a>
  <a href="/stop">Stop</a>
  <a href="/status">Status</a>
</body>
</html>
""")

  def log_message(self, format, *args):
    pass


ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()