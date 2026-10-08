#!/usr/bin/env bash
# Runs scripts/deploy.sh against a local stand-in for the API and checks the
# request it sends and how it treats the answer. No network, no account.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"
trap 'kill "${server_pid:-0}" 2>/dev/null || true; rm -rf "$work"' EXIT

cat > "$work/server.py" <<'PY'
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

out = sys.argv[1]

class Handler(BaseHTTPRequestHandler):
    def do_PATCH(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", "0"))).decode()
        with open(out, "w") as f:
            json.dump({"method": self.command, "path": self.path,
                       "authorization": self.headers.get("Authorization"),
                       "account": self.headers.get("X-Account-ID"),
                       "user_agent": self.headers.get("User-Agent"),
                       "body": json.loads(body)}, f)
        if "refused" in self.path:
            code, answer = 403, {"error": {"message": "This change needs approval."}}
        else:
            code, answer = 200, {"object": "deployment", "id": "dep-1", "type": "web-service",
                                 "name": "api", "status": "Deploying"}
        data = json.dumps(answer).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_PUT(self):
        self.send_response(410)
        self.end_headers()

    def log_message(self, *args):
        pass

server = HTTPServer(("127.0.0.1", 0), Handler)
with open(out + ".port", "w") as f:
    f.write(str(server.server_address[1]))
server.serve_forever()
PY

python3 "$work/server.py" "$work/request.json" &
server_pid=$!
for _ in $(seq 1 50); do [[ -s "$work/request.json.port" ]] && break; sleep 0.1; done
port="$(cat "$work/request.json.port")"

fail() { echo "FAIL: $1"; exit 1; }
got() { jq -r "$1" "$work/request.json"; }

export CS_API_URL="http://127.0.0.1:$port/v2/"
export CS_API_TOKEN="csph_test" CS_ACCOUNT_ID="acct-1"
export CS_IMAGE_TYPE="private" CS_IMAGE_PROVIDER="other"

# 1. A private image with credentials: every field is sent.
CS_DEPLOYMENT_ID="dep-1" CS_IMAGE_NAME="registry.example.com/team/app:1.2.3" \
CS_REGISTRY_URL="registry.example.com" CS_REGISTRY_USERNAME="robot" CS_REGISTRY_PASSWORD='p"a ss' \
  bash "$here/deploy.sh" > "$work/out1.txt" || fail "a 200 answer must succeed"
[[ "$(got .method)" == "PATCH" ]] || fail "method is $(got .method), want PATCH"
[[ "$(got .path)" == "/v2/deployments/dep-1" ]] || fail "path is $(got .path)"
[[ "$(got .authorization)" == "Bearer csph_test" ]] || fail "authorization header"
[[ "$(got .account)" == "acct-1" ]] || fail "account header"
[[ "$(got .user_agent)" == computesphere-* ]] || fail "user agent is $(got .user_agent)"
[[ "$(got .body.image.name)" == "registry.example.com/team/app:1.2.3" ]] || fail "image name"
[[ "$(got .body.image.url)" == "registry.example.com" ]] || fail "registry url"
[[ "$(got .body.image.password)" == 'p"a ss' ]] || fail "a password with a quote and a space must arrive unchanged"
grep -q "Deployment updated" "$work/out1.txt" || fail "success is not reported"
grep -q 'p"a ss' "$work/out1.txt" && fail "the password is printed"

# 2. Only the tag changes: empty registry fields are left out, so saved
#    credentials are kept.
CS_DEPLOYMENT_ID="dep-1" CS_IMAGE_NAME="registry.example.com/team/app:1.2.4" \
CS_REGISTRY_URL="" CS_REGISTRY_USERNAME="" CS_REGISTRY_PASSWORD="" \
  bash "$here/deploy.sh" > /dev/null || fail "a tag-only update must succeed"
[[ "$(got '.body.image | keys | join(",")')" == "name,provider,type" ]] || fail "empty fields were sent: $(got '.body.image | keys | join(",")')"

# 3. A refusal fails the step and prints the platform's message.
if CS_DEPLOYMENT_ID="refused" CS_IMAGE_NAME="app:1" bash "$here/deploy.sh" > "$work/out3.txt"; then
  fail "a 403 answer must fail the step"
fi
grep -q "HTTP 403" "$work/out3.txt" || fail "the status is not reported"
grep -q "This change needs approval." "$work/out3.txt" || fail "the platform's message is not printed"

# 4. A missing input is reported before any request.
rm -f "$work/request.json"
if CS_DEPLOYMENT_ID="" CS_IMAGE_NAME="app:1" bash "$here/deploy.sh" > "$work/out4.txt"; then
  fail "a missing deployment id must fail"
fi
grep -q "deployment_id" "$work/out4.txt" || fail "the missing input is not named"
[[ ! -e "$work/request.json" ]] || fail "a request was sent with a missing input"

echo "ok: 4 cases"
