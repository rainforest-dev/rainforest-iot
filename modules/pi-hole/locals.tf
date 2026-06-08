locals {
  pihole_exporter_script = <<-PYTHON
#!/usr/bin/env python3
"""Pi-hole v6 Prometheus exporter — uses /api/ REST interface (stdlib only)."""
import json, threading, time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.request import urlopen, Request

PIHOLE_URL = "http://localhost:${var.web_port}"
PASSWORD   = "${var.pihole_password}"
PORT       = 9617

_metrics = {}
_lock    = threading.Lock()

def fetch():
    try:
        req = Request(f"{PIHOLE_URL}/api/auth",
                      data=json.dumps({"password": PASSWORD}).encode(),
                      headers={"Content-Type": "application/json"}, method="POST")
        with urlopen(req, timeout=10) as r:
            sid = json.loads(r.read())["session"]["sid"]

        req = Request(f"{PIHOLE_URL}/api/stats/summary", headers={"X-FTL-SID": sid})
        with urlopen(req, timeout=10) as r:
            data = json.loads(r.read())

        Request(f"{PIHOLE_URL}/api/auth", headers={"X-FTL-SID": sid}, method="DELETE")
        return data
    except Exception as e:
        print(f"[pihole-exporter] ERROR: {e}", flush=True)
        return None

def update_loop():
    while True:
        d = fetch()
        if d:
            with _lock:
                _metrics.clear()
                _metrics.update(d)
        time.sleep(30)

def render():
    with _lock:
        d = dict(_metrics)
    if not d:
        return b""
    lines = []
    def g(name, help_, val):
        lines.append(f"# HELP {name} {help_}")
        lines.append(f"# TYPE {name} gauge")
        lines.append(f'{name}{{hostname="localhost"}} {val}')

    def v(key, sub=None):
        x = d.get(key, 0)
        if isinstance(x, dict): x = x.get(sub or "total", 0)
        return x

    g("pihole_dns_queries_today",      "Total DNS queries today",          v("queries"))
    g("pihole_ads_blocked_today",      "Ads/trackers blocked today",       v("blocked"))
    g("pihole_ads_percentage_today",   "Percentage of queries blocked",    v("percent_blocked"))
    g("pihole_unique_domains",         "Unique domains seen",              v("unique_domains"))
    g("pihole_unique_clients",         "Unique clients",                   v("unique_clients"))
    g("pihole_queries_cached",         "Queries answered from cache",      v("cached"))
    g("pihole_queries_forwarded",      "Queries forwarded to upstream",    v("forwarded"))
    g("pihole_domains_being_blocked",  "Domains in gravity blocklist",     d.get("gravity", {}).get("domains_being_blocked", 0))
    status = 1 if d.get("blocking", "enabled") == "enabled" else 0
    g("pihole_status", "Blocking status (1=enabled)", status)
    return ("\n".join(lines) + "\n").encode()

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = render()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4")
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a): pass

if __name__ == "__main__":
    threading.Thread(target=update_loop, daemon=True).start()
    print(f"[pihole-exporter] Pi-hole v6 exporter on :{PORT}", flush=True)
    HTTPServer(("", PORT), Handler).serve_forever()
PYTHON
}
