#!/usr/bin/env bash
# Build the backend's generated API into an image and apply it as a
# Control Plane (cpln) workload. Not run by `effortless build`; run it yourself:
#
#   ./deploy/deploy.sh
#
# The cpln token comes from env SEED_SECRET_cplnToken, else from
# seed-secret-values.json beside this script. It is never printed.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CPLN_ORG="$cplnOrg$"
CPLN_GVC="$cplnGvc$"
WORKLOAD="$workloadName$"
API_DIR="${API_DIR:-$HERE/../backend/api}"
PORT=42441

token="${SEED_SECRET_cplnToken:-}"
if [ -z "$token" ] && [ -f "$HERE/seed-secret-values.json" ]; then
  token="$(node -e '
    const r = (JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).replacements || [])
      .find((x) => String(x.key).toLowerCase() === "cplntoken");
    process.stdout.write(r && r.value ? String(r.value) : "");
  ' "$HERE/seed-secret-values.json")"
fi
if [ -z "$token" ]; then
  echo "deploy.sh: no cpln token. Set SEED_SECRET_cplnToken or put it in $HERE/seed-secret-values.json." >&2
  exit 1
fi
export CPLN_TOKEN="$token"
unset token

if [ ! -f "$API_DIR/package.json" ]; then
  echo "deploy.sh: no generated API at $API_DIR. Run 'effortless buildWithSubprojects' at the project root first." >&2
  exit 1
fi

TAG="$(date -u +%Y%m%d%H%M%S)"
IMAGE="$WORKLOAD:$TAG"

echo "Building $IMAGE from $API_DIR (org $CPLN_ORG)"
cpln image build --org "$CPLN_ORG" --name "$IMAGE" --dir "$API_DIR" --dockerfile "$HERE/Dockerfile" --push

env_yaml=""
for v in PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE; do
  if [ -n "${!v:-}" ]; then
    env_yaml="$env_yaml
        - name: $v
          value: '${!v}'"
  fi
done

echo "Applying workload $WORKLOAD to gvc $CPLN_GVC"
cpln apply --org "$CPLN_ORG" --gvc "$CPLN_GVC" --file - <<YAML
kind: workload
name: $WORKLOAD
spec:
  type: standard
  containers:
    - name: api
      image: //image/$IMAGE
      cpu: 250m
      memory: 512Mi
      ports:
        - number: $PORT
          protocol: http
      env:
        - name: PORT
          value: '$PORT'$env_yaml
  defaultOptions:
    capacityAI: false
    autoscaling:
      minScale: 1
      maxScale: 1
  firewallConfig:
    external:
      inboundAllowCIDR:
        - 0.0.0.0/0
      outboundAllowCIDR:
        - 0.0.0.0/0
YAML

echo "Done. Endpoint: cpln workload get $WORKLOAD --org $CPLN_ORG --gvc $CPLN_GVC"
