#!/usr/bin/env python3
"""Same-origin proxy so the Gumloop preview can reach Supabase (no browser CORS).
Forwards the user request unchanged. The deployed mint function owns Cover validation and provider routing.
"""
import os, json, base64, urllib.request, urllib.error, urllib.parse

URL = "https://ucnruxztueysdohgamdy.supabase.co"
ANON = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVjbnJ1eHp0dWV5c2RvaGdhbWR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2OTE2NzcsImV4cCI6MjA5OTI2NzY3N30.-fJF0jiS4avyWvXE6VLKZCpVECjultBteNAIxXogCfM"


def out(ok, status, obj):
    print(json.dumps({"ok": ok, "status": status, "obj": obj}))


def http(url, method="GET", token=None, data=None, content_type="application/json", upsert=False, timeout=80):
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("apikey", ANON)
    req.add_header("Authorization", "Bearer " + (token or ANON))
    if data is not None:
        req.add_header("Content-Type", content_type or "application/json")
    if upsert:
        req.add_header("x-upsert", "true")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


payload = json.loads(os.getenv("GUMLOOP_PAYLOAD") or "{}")
path = payload.get("path") or ""
if not isinstance(path, str) or not path.startswith("/") or "://" in path or ".." in path:
    out(False, 400, {"error": "bad path"})
    raise SystemExit(0)

method = str(payload.get("method") or "GET").upper()
if method not in ("GET", "POST", "PUT", "PATCH", "DELETE"):
    out(False, 400, {"error": "bad method"})
    raise SystemExit(0)

token = payload.get("token") or ANON
if not isinstance(token, str) or len(token) > 8000:
    token = ANON

query = payload.get("query")
url = URL + path
if isinstance(query, dict) and query:
    url += ("&" if "?" in url else "?") + urllib.parse.urlencode({k: str(v) for k, v in query.items()})

raw_b64 = payload.get("rawB64")
body = payload.get("body")

content_type = payload.get("contentType") or "application/json"
data = None
try:
    if raw_b64:
        data = base64.b64decode(raw_b64)
    elif body is not None:
        data = json.dumps(body).encode()
except Exception as e:
    out(False, 400, {"error": "bad body: " + str(e)})
    raise SystemExit(0)

status, raw_bytes = http(
    url, method, token=token, data=data, content_type=content_type, upsert=bool(payload.get("upsert"))
)
raw = raw_bytes.decode("utf-8", "replace") if raw_bytes else ""
try:
    obj = json.loads(raw) if raw else {}
except Exception:
    obj = {"error": raw[:800]}
out(200 <= status < 300, status, obj)
