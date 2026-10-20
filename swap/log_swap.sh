#!/usr/bin/env bash
# Ultra-lightweight Swap & Memory Logger (Outputs JSONL)

OUT_DIR="/opt/swap-tracker"
LOG_FILE="$OUT_DIR/swap_history.jsonl"
MAX_LINES=8640 # Keep 30 days of 5-minute intervals

TS=$(date +"%Y-%m-%d %H:%M:%S")

# 1. Read Global Memory from /proc/meminfo (in MB)
eval $(awk '
  /^MemTotal:/ {mt=int($2/1024)}
  /^MemFree:/ {mf=int($2/1024)}
  /^MemAvailable:/ {ma=int($2/1024)}
  /^Buffers:/ {mb=int($2/1024)}
  /^Cached:/ {mc=int($2/1024)}
  /^Shmem:/ {ms=int($2/1024)}
  /^SwapTotal:/ {st=int($2/1024)}
  /^SwapFree:/ {sf=int($2/1024)}
  END {
    used = mt - ma
    cache = mb + mc
    sused = st - sf
    printf "MEM_USED=%d MEM_AVAIL=%d MEM_CACHE=%d MEM_SHM=%d SWAP_USED=%d", used, ma, cache, ms, sused
  }
' /proc/meminfo)

# 2. Map Docker Container IDs to Names once per run
declare -A C_NAMES
while read -r id name; do
  [ -n "$id" ] && C_NAMES["$id"]="$name"
done < <(docker ps --no-trunc --format '{{.ID}} {{.Names}}' 2>/dev/null)

# 3. Read Cgroup v2 Swap & RAM per Docker Container
CG_JSON=""
for id in "${!C_NAMES[@]}"; do
   cname="${C_NAMES[$id]}"
   cg_path="/sys/fs/cgroup/system.slice/docker-${id}.scope"
   if [ -d "$cg_path" ]; then
    c_swap=$(awk '{print int($1/1048576)}' "$cg_path/memory.swap.current" 2>/dev/null || echo 0)
    c_ram=$(awk '{print int($1/1048576)}' "$cg_path/memory.current" 2>/dev/null || echo 0)
    if [ "$c_swap" -gt 0 ] || [ "$c_ram" -gt 50 ]; then
      [ -n "$CG_JSON" ] && CG_JSON="${CG_JSON},"
      CG_JSON="${CG_JSON}\"${cname}\":{\"swap\":${c_swap},\"ram\":${c_ram}}"
    fi
  fi
done

# 4. Read Top Individual Processes in Swap (>5MB) aggregated by Container+Command
PROC_JSON=$(awk '
  FILENAME ~ /status$/ {
    pid = FILENAME; sub(/\/proc\//, "", pid); sub(/\/status/, "", pid)
    if ($1 == "Name:") name[pid] = $2
    if ($1 == "VmSwap:") swap[pid] = int($2 / 1024)
  }
  FILENAME ~ /cgroup$/ {
    pid = FILENAME; sub(/\/proc\//, "", pid); sub(/\/cgroup/, "", pid)
    if (match($0, /docker-[a-f0-9]{64}/)) {
      cid[pid] = substr($0, RSTART+7, 64)
    }
  }
  END {
    for (p in swap) {
      if (swap[p] >= 5) {
        c = (p in cid) ? cid[p] : "Host_OS"
        printf "%s\t%s\t%d\n", c, name[p], swap[p]
      }
    }
  }
' /proc/[0-9]*/status /proc/[0-9]*/cgroup 2>/dev/null | while IFS=$'\t' read -r cid comm swp; do
  if [ "$cid" != "Host_OS" ] && [ -n "${C_NAMES[$cid]}" ]; then
    label="[${C_NAMES[$cid]}] $comm"
  else
    label="[Host] $comm"
  fi
  printf "%s\t%d\n" "$label" "$swp"
done | awk -F'\t' '
  { tot[$1] += $2; cnt[$1]++ }
  END {
    first = 1
    for (k in tot) {
      if (!first) printf ","
      first = 0
      gsub(/"/, "\\\"", k)
      label = (cnt[k] > 1) ? sprintf("%s (%dx)", k, cnt[k]) : k
      printf "\"%s\":%d", label, tot[k]
    }
  }
')

# 5. Append single-line JSON record
printf '{"ts":"%s","host":{"ram_used":%d,"ram_avail":%d,"cache":%d,"shm":%d,"swap_used":%d},"containers":{%s},"procs":{%s}}\n' \
  "$TS" "$MEM_USED" "$MEM_AVAIL" "$MEM_CACHE" "$MEM_SHM" "$SWAP_USED" "$CG_JSON" "$PROC_JSON" >> "$LOG_FILE"

# 6. Rotate file if it exceeds 30 days of lines
LINE_CNT=$(wc -l < "$LOG_FILE")
if [ "$LINE_CNT" -gt 9000 ]; then
  tail -n "$MAX_LINES" "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi
