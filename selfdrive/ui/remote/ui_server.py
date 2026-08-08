#!/usr/bin/env python3

import json
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

PORT = 8080

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CAPTURE_FILE = "/data/ui_capture.jpg"
CLICK_FILE = "/data/ui_remote_click"


class Handler(SimpleHTTPRequestHandler):
  def __init__(self, *args, **kwargs):
    super().__init__(*args, directory=SCRIPT_DIR, **kwargs)

  def do_GET(self):
    path = self.path.split("?", 1)[0]

    # Screenshot is generated at runtime in /data.
    if path == "/ui_capture.jpg":
      try:
        with open(CAPTURE_FILE, "rb") as f:
          data = f.read()

        self.send_response(200)
        self.send_header("Content-Type", "image/jpeg")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.end_headers()
        self.wfile.write(data)

      except FileNotFoundError:
        self.send_error(404, "UI capture not available yet")

      return

    super().do_GET()

  def do_POST(self):
    if self.path != "/click":
      self.send_error(404)
      return

    try:
      length = int(self.headers.get("Content-Length", "0"))
      data = json.loads(self.rfile.read(length))

      x = max(0.0, min(1.0, float(data["x"])))
      y = max(0.0, min(1.0, float(data["y"])))

      tmp = CLICK_FILE + ".tmp"

      with open(tmp, "w") as f:
        f.write(f"{x:.6f} {y:.6f}\n")

      os.replace(tmp, CLICK_FILE)

      self.send_response(204)
      self.end_headers()

    except Exception as e:
      self.send_error(400, str(e))

  def log_message(self, format, *args):
    pass


class ReusableHTTPServer(ThreadingHTTPServer):
  allow_reuse_address = True


ReusableHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()