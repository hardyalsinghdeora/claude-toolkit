#!/bin/zsh
# cindex-refresh.sh — rebuild cindex indexes for every code folder in
# ~/Workspace, driven by a launchd agent. Pure shell:
# no Claude session is involved, so a run costs zero tokens.
#
# A folder counts as code if it has .git, or contains at least one source
# file within 3 levels. Logs to ~/.claude/code-index/logs/cron.log; cindex
# itself also logs each build to logs/cindex.log.

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

WORKSPACE="$HOME/Workspace"
LOG="$HOME/.claude/code-index/logs/cron.log"
mkdir -p "${LOG:h}"

log() { print -r -- "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

# keep the log small
if [[ -f "$LOG" && $(wc -c < "$LOG") -gt 262144 ]]; then
  tail -n 200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

has_code() {
  [[ -d "$1/.git" ]] && return 0
  find "$1" -maxdepth 3 \( -name node_modules -o -name .git -o -name venv -o -name .venv \) -prune \
    -o -type f \( -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.tsx' \
    -o -name '*.java' -o -name '*.kt' -o -name '*.go' -o -name '*.php' \
    -o -name '*.rb' -o -name '*.rs' -o -name '*.sql' -o -name '*.sh' \) \
    -print -quit 2>/dev/null | grep -q .
}

log "refresh sweep start"
ok=0 fail=0 skip=0
for d in "$WORKSPACE"/*/; do
  d="${d%/}"
  if has_code "$d"; then
    if out=$(cindex refresh --path "$d" 2>&1); then
      ok=$((ok+1))
    else
      fail=$((fail+1)); log "FAILED $d: $out"
    fi
  else
    skip=$((skip+1))
  fi
done
log "refresh sweep done: $ok refreshed, $fail failed, $skip skipped"
