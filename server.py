import http.server
import socketserver

class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()
    def log_message(self, format, *args):
        pass  # silenciar logs

PORT = 8080
with socketserver.TCPServer(("", PORT), NoCacheHandler) as httpd:
    print(f"Servidor rodando em http://localhost:{PORT}")
    httpd.serve_forever()
