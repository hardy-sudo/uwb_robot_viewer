"""
내부망 프록시 서버

실행: python proxy_server.py
- PC에서 실행하면 스마트폰(같은 Wi-Fi)에서 웹앱으로 로봇 제어 가능
- 스마트폰 브라우저에서 http://<이 PC의 IP>:8080 접속
"""

import http.server
import urllib.request
import urllib.error
import json
import os

RCS_BASE  = "http://10.0.4.104:7000"
PROXY_PORT = 8080
HTML_FILE  = os.path.join(os.path.dirname(__file__), "robot_control.html")


class ProxyHandler(http.server.BaseHTTPRequestHandler):

    def log_message(self, fmt, *args):
        print(f"[PROXY] {self.address_string()} {fmt % args}")

    # ── GET / → HTML 파일 전송 ───────────────────────────────────────────
    def do_GET(self):
        if self.path in ("/", "/index.html"):
            try:
                with open(HTML_FILE, "rb") as f:
                    data = f.read()
                self._send(200, "text/html; charset=utf-8", data)
            except FileNotFoundError:
                self._send(404, "text/plain", b"robot_control.html not found")
        else:
            self._send(404, "text/plain", b"Not Found")

    # ── POST /ics/... → RCS 서버로 포워딩 ──────────────────────────────
    def do_POST(self):
        length  = int(self.headers.get("Content-Length", 0))
        body    = self.rfile.read(length)
        target  = RCS_BASE + self.path

        req = urllib.request.Request(
            target,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=6) as resp:
                resp_body = resp.read()
                self._send(resp.status, "application/json", resp_body)
        except urllib.error.HTTPError as e:
            self._send(e.code, "application/json", e.read())
        except Exception as e:
            err = json.dumps({"code": -1, "desc": str(e)}).encode()
            self._send(502, "application/json", err)

    # ── OPTIONS (CORS preflight) ─────────────────────────────────────────
    def do_OPTIONS(self):
        self.send_response(204)
        self._cors_headers()
        self.end_headers()

    # ── 헬퍼 ────────────────────────────────────────────────────────────
    def _send(self, code: int, content_type: str, body: bytes):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", len(body))
        self._cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def _cors_headers(self):
        self.send_header("Access-Control-Allow-Origin",  "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")


if __name__ == "__main__":
    import socket
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)

    server = http.server.HTTPServer(("0.0.0.0", PROXY_PORT), ProxyHandler)
    print("=" * 50)
    print(f"  프록시 서버 시작")
    print(f"  RCS 서버  : {RCS_BASE}")
    print(f"  접속 주소 : http://{local_ip}:{PROXY_PORT}")
    print(f"  스마트폰  : 같은 Wi-Fi 연결 후 위 주소로 접속")
    print("=" * 50)
    print("  종료: Ctrl+C")
    print()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n서버 종료")
