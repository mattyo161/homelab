#!/usr/bin/env bash
set -euo pipefail

# Small comparative load test for PlantUML servers.
# - Tests multiple diagram complexities.
# - Injects a unique timestamp into every request to avoid cache hits.

HOSTS=(
  # "plantuml.manjaro.internal"
  # "plantuml.rpi.internal" 
  "plantuml.oue.home"
  )
DIAGRAMS=("simple" "medium" "complex")
RUNS=4
REQUESTS_PER_RUN=8
CONCURRENCY=4
SCHEME="http"
IMAGE_TYPE="svg"
IMAGE_TEST=""
ENDPOINT=""
OUT_DIR="${TMPDIR:-/tmp}/plantuml-load-test"

usage() {
  cat <<'EOF'
Usage: load-test.sh [options]

Options:
  --hosts "h1,h2"        Comma-separated host list.
  --runs N               Number of runs per diagram/host. Default: 4
  --requests N           Requests per run per diagram/host. Default: 8
  --concurrency N        Max concurrent requests. Default: 4
  --scheme http|https    URL scheme. Default: 
  --image-type TYPE      Image type. Default: svg
  --endpoint PATH        Render endpoint path. Default: /svg
  --out-dir PATH         Output directory. Default: /tmp/plantuml-load-test
  -h, --help             Show this help.

Example:
  ./plantuml/load-test.sh --runs 6 --requests 12 --concurrency 6
EOF
}

join_by() {
  local IFS="$1"
  shift
  echo "$*"
}

acquire_lock() {
  local lock_path="$1"
  while ! mkdir "$lock_path" 2>/dev/null; do
    sleep 0.01
  done
}

release_lock() {
  local lock_path="$1"
  rmdir "$lock_path"
}

render_diagram() {
  local kind="$1"
  local stamp="$2"

  case "$kind" in
    simple)
      cat <<EOF
@startuml
title Simple Diagram - ${stamp}
actor User
participant "PlantUML Server" as S
User -> S: Render request (${stamp})
S --> User: SVG response
note right of S
  cache-bust: ${stamp}
end note
@enduml
EOF
      ;;
    medium)
      cat <<EOF
@startuml
title Medium Sequence - ${stamp}
skinparam sequenceMessageAlign center
autonumber
actor Browser
participant Ingress
participant "PlantUML API" as API
database Cache
database Storage

Browser -> Ingress: POST /svg (${stamp})
Ingress -> API: Forward request
API -> Cache: Lookup by source hash
alt cache miss
  API -> Storage: Load includes
  Storage --> API: Resources
  API -> API: Parse + layout
  API -> Cache: Store render
else cache hit
  Cache --> API: SVG bytes
end
API --> Ingress: 200 image/svg+xml
Ingress --> Browser: SVG (${stamp})
@enduml
EOF
      ;;
    complex)
      cat <<EOF
@startuml
title Complex Architecture - ${stamp}
left to right direction
skinparam packageStyle rectangle
skinparam shadowing false
skinparam componentStyle rectangle
skinparam linetype ortho

cloud "Users" as users
node "Edge" {
  [DNS]
  [Ingress]
}

package "K3s Cluster" {
  frame "plantuml namespace" {
    component "plantuml-server" as app
    component "metrics-exporter" as met
  }
  frame "kube-system" {
    component "coredns" as dns
    component "kube-proxy" as proxy
  }
}

database "Image Cache" as cache
database "Object Store" as store
queue "Render Queue" as queue
collections "Request Log" as log

users --> [DNS] : lookup
[DNS] --> [Ingress] : ${stamp}
[Ingress] --> proxy
proxy --> app : /svg
app --> cache : read/write
app --> queue : enqueue job
queue --> app : dequeue
app --> store : include fetch
app --> met : export metrics
app --> log : append render event ${stamp}
dns --> app : service discovery
app --> [Ingress] : svg bytes
[Ingress] --> users : response

note bottom of app
  Unique stamp per request:
  ${stamp}
end note
@enduml
EOF
      ;;
    *)
      echo "Unknown diagram type: $kind" >&2
      return 1
      ;;
  esac
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --hosts)
        IFS=',' read -r -a HOSTS <<< "$2"
        shift 2
        ;;
      --runs)
        RUNS="$2"
        shift 2
        ;;
      --requests)
        REQUESTS_PER_RUN="$2"
        shift 2
        ;;
      --concurrency)
        CONCURRENCY="$2"
        shift 2
        ;;
      --scheme)
        SCHEME="$2"
        shift 2
        ;;
      --endpoint)
        ENDPOINT="$2"
        shift 2
        ;;
      --image-type)
        IMAGE_TYPE="$2"
        shift 2
        ;;
      --image-test)
        IMAGE_TEST="$2"
        shift 2
        ;;
      --out-dir)
        OUT_DIR="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
  done
  # if ENDPINT is not set then it should match the IMAGE_TYPE
  if [[ -z "$ENDPOINT" ]]; then
    ENDPOINT="/${IMAGE_TYPE}"
  fi
  if [[ -z "$IMAGE_TEST" ]]; then
    if [[ "$IMAGE_TYPE" == "svg" ]]; then
      IMAGE_TEST="<svg"
    elif [[ "$IMAGE_TYPE" == "png" ]]; then
      IMAGE_TEST="png"
    # TODO: eventually we can add txt and pdf support
    elif [[ "$IMAGE_TYPE" == "pdf" ]]; then
      IMAGE_TEST="pdf"
    elif [[ "$IMAGE_TYPE" == "txt" ]]; then
      IMAGE_TEST="txt"
    else
      echo "Unknown image type: $IMAGE_TYPE" >&2
      exit 1
    fi
  fi
}

run_one_request() {
  local host="$1"
  local diagram="$2"
  local run_idx="$3"
  local req_idx="$4"
  local csv="$5"

  local stamp
  stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)-${run_idx}-${req_idx}-$RANDOM"

  local source
  source="$(render_diagram "$diagram" "$stamp")"

  local url="${SCHEME}://${host}${ENDPOINT}"
  local body_file
  body_file="$(mktemp "${OUT_DIR}/response.XXXXXX")"

  local curl_meta http_code elapsed_s elapsed_ms bytes ok
  curl_meta="$(curl -sS -o "$body_file" -w '%{http_code} %{time_total}' \
    -H 'Content-Type: text/plain; charset=utf-8' \
    --data-raw "$source" \
    "$url" || echo "000 0")"
  http_code="${curl_meta%% *}"
  elapsed_s="${curl_meta##* }"
  elapsed_ms="$(awk -v t="$elapsed_s" 'BEGIN { printf "%.2f", t * 1000 }')"
  bytes="$(wc -c < "$body_file" | tr -d ' ')"

  if [[ "$http_code" == "200" ]] && grep -qi "${IMAGE_TEST}" "$body_file"; then
    ok=1
  else
    ok=0
  fi

  local lock_path="${csv}.lockdir"
  acquire_lock "$lock_path"
  printf "%s,%s,%s,%s,%s,%s,%s,%s\n" \
    "$host" "$diagram" "$run_idx" "$req_idx" "$elapsed_ms" "$http_code" "$bytes" "$ok" >> "$csv"
  release_lock "$lock_path"

  rm -f "$body_file"
}

wait_for_slot() {
  local csv="$1"
  local host="$2"
  local total_requests="$3"
  local host_total="$4"
  local host_start_done="$5"
  while (( $(jobs -pr | wc -l | tr -d ' ') >= CONCURRENCY )); do
    show_progress_line "$csv" "$host" "$total_requests" "$host_total" "$host_start_done"
    sleep 0.05
  done
}

completed_count() {
  local csv="$1"
  awk 'END { if (NR > 0) print NR - 1; else print 0 }' "$csv"
}

show_progress_line() {
  local csv="$1"
  local host="$2"
  local total_requests="$3"
  local host_total="$4"
  local host_start_done="$5"
  local spinner='-\|/'
  local running done_total done_host
  local pct_total pct_host spin

  running="$(jobs -pr | wc -l | tr -d ' ')"
  done_total="$(completed_count "$csv")"
  done_host=$(( done_total - host_start_done ))
  if (( done_host < 0 )); then
    done_host=0
  fi
  spin="${spinner:PROGRESS_TICK%4:1}"
  pct_total="$(awk -v d="$done_total" -v t="$total_requests" 'BEGIN { if (t > 0) printf "%.1f", (d*100)/t; else printf "100.0" }')"
  pct_host="$(awk -v d="$done_host" -v t="$host_total" 'BEGIN { if (t > 0) printf "%.1f", (d*100)/t; else printf "100.0" }')"
  printf "\r[%s] Progress total %d/%d (%s%%) | host %s: %d/%d (%s%%) | active=%d" \
    "$spin" "$done_total" "$total_requests" "$pct_total" "$host" "$done_host" "$host_total" "$pct_host" "$running"
  PROGRESS_TICK=$((PROGRESS_TICK + 1))
}

wait_with_progress() {
  local csv="$1"
  local host="$2"
  local total_requests="$3"
  local host_total="$4"
  local host_start_done="$5"

  while true; do
    show_progress_line "$csv" "$host" "$total_requests" "$host_total" "$host_start_done"
    if (( $(jobs -pr | wc -l | tr -d ' ') == 0 )); then
      break
    fi
    sleep 0.2
  done
  printf "\n"
}

print_summary() {
  local csv="$1"
  echo
  echo "Results file: $csv"
  echo
  awk -F, '
    NR > 1 {
      key = $1 FS $2
      count[key]++
      total_ms[key] += $5
      if (!(key in min_ms) || $5 < min_ms[key]) min_ms[key] = $5
      if (!(key in max_ms) || $5 > max_ms[key]) max_ms[key] = $5
      if ($8 == 1) ok[key]++
      if ($6 != 200) non200[key]++
    }
    END {
      printf "%-26s %-10s %8s %10s %10s %10s %10s %8s %8s\n", "HOST", "DIAGRAM", "REQS", "OK", "AVG_MS", "MIN_MS", "MAX_MS", "NON200", "STATUS"
      for (k in count) {
        split(k, parts, FS)
        host = parts[1]
        diagram = parts[2]
        avg = (count[k] ? total_ms[k] / count[k] : 0)
        n200 = (k in non200 ? non200[k] : 0)
        oks = (k in ok ? ok[k] : 0)
        status = (n200 == 0 && oks == count[k]) ? "✅" : "❌"
        printf "%-26s %-10s %8d %10d %10.2f %10.2f %10.2f %8d %8s\n", host, diagram, count[k], oks, avg, min_ms[k], max_ms[k], n200, status
      }
    }
  ' "$csv" | sort
  echo
  echo "Tip: lower AVG/MS and MAX/MS is better."
}

main() {
  parse_args "$@"
  PROGRESS_TICK=0

  mkdir -p "$OUT_DIR"
  local csv="${OUT_DIR}/results-$(date +%Y%m%d-%H%M%S).csv"
  local total_requests
  local requests_per_host
  total_requests=$(( ${#HOSTS[@]} * ${#DIAGRAMS[@]} * RUNS * REQUESTS_PER_RUN ))
  requests_per_host=$(( ${#DIAGRAMS[@]} * RUNS * REQUESTS_PER_RUN ))
  echo "host,diagram,run,request,elapsed_ms,http_code,bytes,ok" > "$csv"

  echo "Starting load test..."
  echo "Hosts      : $(join_by ', ' "${HOSTS[@]}")"
  echo "Diagrams   : $(join_by ', ' "${DIAGRAMS[@]}")"
  echo "Runs       : $RUNS"
  echo "Req/Run    : $REQUESTS_PER_RUN"
  echo "Concurrency: $CONCURRENCY"
  echo "Imagetype  : ${IMAGE_TYPE}"
  echo "Endpoint   : ${SCHEME}://<host>${ENDPOINT}"

  for host in "${HOSTS[@]}"; do
    local host_start_done
    host_start_done="$(completed_count "$csv")"
    echo
    echo "Testing host: ${host}"
    for diagram in "${DIAGRAMS[@]}"; do
      for run_idx in $(seq 1 "$RUNS"); do
        for req_idx in $(seq 1 "$REQUESTS_PER_RUN"); do
          wait_for_slot "$csv" "$host" "$total_requests" "$requests_per_host" "$host_start_done"
          run_one_request "$host" "$diagram" "$run_idx" "$req_idx" "$csv" &
        done
      done
    done
    # Ensure strict host isolation for fair A/B comparison.
    wait_with_progress "$csv" "$host" "$total_requests" "$requests_per_host" "$host_start_done"
  done

  print_summary "$csv"
}

main "$@"
