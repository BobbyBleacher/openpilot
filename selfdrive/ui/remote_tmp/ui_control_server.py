#!/usr/bin/env python3

import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


PORT = 8081


class Handler(BaseHTTPRequestHandler):
  def do_GET(self):
    if self.path == "/start":
      result = subprocess.run(
        ["/data/ui_remote.sh", "start"],
        capture_output=True,
        text=True,
      )

      self.send_response(302)
      self.send_header("Location", "http://%s:8080/ui.html" % self.headers["Host"].split(":")[0])
      self.end_headers()
      return

    if self.path == "/stop":
      result = subprocess.run(
        ["/data/ui_remote.sh", "stop"],
        capture_output=True,
        text=True,
      )

      self.send_response(200)
      self.send_header("Content-Type", "text/plain")
      self.end_headers()
      self.wfile.write(result.stdout.encode())
      return

    if self.path == "/status":
      result = subprocess.run(
        ["/data/ui_remote.sh", "status"],
        capture_output=True,
        text=True,
      )

      self.send_response(200)
      self.send_header("Content-Type", "text/plain")
      self.end_headers()
      self.wfile.write(result.stdout.encode())
      return

    self.send_response(200)
    self.send_header("Content-Type", "text/html")
    self.end_headers()

    self.wfile.write(b"""
    <!doctype html>
    <html>
      <head>
        <title>Comma Remote UI</title>
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
