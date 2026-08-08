#!/usr/bin/env python3

import json
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

os.chdir("/data")

class Handler(SimpleHTTPRequestHandler):
  def do_POST(self):
    if self.path != "/click":
      self.send_error(404)
      return

    try:
      length = int(self.headers.get("Content-Length", "0"))
      data = json.loads(self.rfile.read(length))

      x = max(0.0, min(1.0, float(data["x"])))
      y = max(0.0, min(1.0, float(data["y"])))

      tmp = "/data/ui_remote_click.tmp"
      final = "/data/ui_remote_click"

      with open(tmp, "w") as f:
        f.write(f"{x:.6f} {y:.6f}\n")

      os.replace(tmp, final)

      self.send_response(204)
      self.end_headers()

    except Exception as e:
      self.send_error(400, str(e))

ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
