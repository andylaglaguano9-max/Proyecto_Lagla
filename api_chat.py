import http.server
import json
import urllib.request
import threading

OLLAMA_HOST = "http://localhost:11434"
MODELO = "qwen2.5-coder:7b"
PUERTO = 8000

class ChatHandler(http.server.BaseHTTPRequestHandler):

    def do_GET(self):
        if self.path == "/chat":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            respuesta = {
                "modelo": MODELO,
                "mensaje": "hello world",
                "status": "ok"
            }
            self.wfile.write(json.dumps(respuesta).encode("utf-8"))
        elif self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"mensaje": "hello point", "status": "ok"}).encode("utf-8"))
        else:
            self.send_response(404)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "not found"}).encode("utf-8"))

    def do_POST(self):
        if self.path == "/chat":
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length) if content_length else b"{}"
            try:
                data = json.loads(body)
            except json.JSONDecodeError:
                data = {}

            prompt = data.get("prompt", "Di hello world en español")
            prompt_data = json.dumps({
                "model": MODELO,
                "prompt": prompt,
                "stream": False
            }).encode("utf-8")

            req = urllib.request.Request(
                f"{OLLAMA_HOST}/api/generate",
                data=prompt_data,
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            with urllib.request.urlopen(req, timeout=120) as resp:
                ollama_resp = json.loads(resp.read().decode("utf-8"))

            respuesta = {
                "modelo": MODELO,
                "prompt": prompt,
                "respuesta": ollama_resp.get("response", "").strip(),
                "status": "ok"
            }
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(respuesta).encode("utf-8"))
        else:
            self.send_response(404)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "not found"}).encode("utf-8"))

    def log_message(self, format, *args):
        print(f"[API] {args[0]} {args[1]} {args[2]}")

if __name__ == "__main__":
    server = http.server.ThreadingHTTPServer(("0.0.0.0", PUERTO), ChatHandler)
    print(f"[API] Servidor iniciado en http://0.0.0.0:{PUERTO}")
    print(f"[API] Endpoints:")
    print(f"      GET  /chat  -> hello world")
    print(f"      POST /chat  -> {MODELO}")
    print(f"      GET  /health -> hello point")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[API] Servidor detenido")
        server.server_close()
