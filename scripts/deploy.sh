#!/usr/bin/env bash
# Tells ComputeSphere to roll a deployment to a new image.
#
#   PATCH <api>/deployments/<id>   {"image": {...}}
#
# Inputs come from the environment, never from text spliced into this
# script, so a value with quotes or spaces is passed as it is:
#
#   CS_API_URL        API base (default https://api.computesphere.com/v2)
#   CS_API_TOKEN      a ComputeSphere API token (starts with csph_)
#   CS_ACCOUNT_ID     the account id
#   CS_DEPLOYMENT_ID  the deployment to update
#   CS_IMAGE_NAME     full image name with tag or digest
#   CS_IMAGE_TYPE     public | private
#   CS_IMAGE_PROVIDER other | ecr | gcr | ...
#   CS_REGISTRY_URL   registry endpoint (private images)
#   CS_REGISTRY_USERNAME, CS_REGISTRY_PASSWORD  registry credentials
#   CS_API_MAX_TIME   seconds to wait for the API's answer (default 120)
#
# An empty registry field is left out of the request: the platform keeps the
# credentials it has saved when only the image name or tag changes.
set -euo pipefail

API_URL="${CS_API_URL:-https://api.computesphere.com/v2}"
API_URL="${API_URL%/}"

missing=()
[[ -n "${CS_API_TOKEN:-}" ]] || missing+=("token")
[[ -n "${CS_ACCOUNT_ID:-}" ]] || missing+=("account_id")
[[ -n "${CS_DEPLOYMENT_ID:-}" ]] || missing+=("deployment_id")
[[ -n "${CS_IMAGE_NAME:-}" ]] || missing+=("name")
if (( ${#missing[@]} )); then
  echo "Deploy needs these inputs: ${missing[*]}"
  exit 1
fi

payload=$(jq -n \
  --arg name "$CS_IMAGE_NAME" \
  --arg type "${CS_IMAGE_TYPE:-}" \
  --arg provider "${CS_IMAGE_PROVIDER:-}" \
  --arg url "${CS_REGISTRY_URL:-}" \
  --arg username "${CS_REGISTRY_USERNAME:-}" \
  --arg password "${CS_REGISTRY_PASSWORD:-}" \
  '{image: ({name: $name, type: $type, provider: $provider, url: $url, username: $username, password: $password}
            | with_entries(select(.value != "")))}')

echo "Deploying image $CS_IMAGE_NAME to ComputeSphere..."

# The payload (registry password included) goes in on stdin, never on the
# command line, where other processes could read it. One attempt, no retry:
# a deploy sent twice would roll twice.
MAX_TIME="${CS_API_MAX_TIME:-120}"
rc=0
response=$(printf '%s' "$payload" | curl -sS --max-time "$MAX_TIME" -w "\nHTTP_STATUS:%{http_code}" -X PATCH "$API_URL/deployments/$CS_DEPLOYMENT_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CS_API_TOKEN" \
  -H "X-Account-ID: $CS_ACCOUNT_ID" \
  -H "User-Agent: ${CS_USER_AGENT:-computesphere-deploy-action}" \
  --data-binary @-) || rc=$?
if (( rc == 28 )); then
  echo "Deploy failed: the ComputeSphere API did not answer within ${MAX_TIME} seconds."
  echo "The deploy may still have been accepted. Check the deployment in the ComputeSphere console before running this job again."
  exit 1
elif (( rc != 0 )); then
  echo "Deploy failed: the ComputeSphere API could not be reached."
  exit 1
fi

status=$(printf '%s' "$response" | sed -n 's/^HTTP_STATUS://p' | tail -n1)
body=$(printf '%s' "$response" | sed '/^HTTP_STATUS:/d')

field() { printf '%s' "$body" | jq -r "$1 // empty" 2>/dev/null || true; }

if [[ "$status" == "200" ]]; then
  echo "Deployment updated."
  echo "------------------------------------------"
  echo "Deployment:  $(field '.name')"
  echo "Id:          $(field '.id')"
  echo "Status:      $(field '.status')"
  echo "Image:       $CS_IMAGE_NAME"
  echo "------------------------------------------"
  exit 0
fi

# The API answers errors as problem details: the sentence is in "detail".
message=$(field '.detail')
[[ -n "$message" ]] || message=$(field '.error.message')
[[ -n "$message" ]] || message=$(field '.message')
[[ -n "$message" ]] || message=$(field '.title')
[[ -n "$message" ]] || message="no message in the answer"
echo "Deploy failed (HTTP ${status:-unknown}): $message"
request_id=$(field '.request_id')
[[ -z "$request_id" ]] || echo "Request id: $request_id (quote it if you contact support)"
case "$status" in
  401) echo "The API token was rejected. Use a ComputeSphere API token (it starts with csph_), stored as a secret and passed as 'token'." ;;
  403) echo "The token is not allowed to change this deployment. Check the token's access and the project's rules for automated changes." ;;
  404) echo "No deployment with id '$CS_DEPLOYMENT_ID' was found for this account." ;;
esac
exit 1
