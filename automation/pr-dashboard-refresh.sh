#!/bin/zsh
# pr-dashboard-refresh.sh — headless PR dashboard refresh, driven by launchd.
# Runs the pr-dashboard skill via a fresh headless `claude -p` session.
#
# Bounded to business hours 9:00–18:00: launchd's StartCalendarInterval only
# fires in-hours, but RunAtLoad fires at every login regardless of time, so we
# guard here too — a laptop turned on at 2am must not kick off a run.

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
cd "$HOME" || exit 1

AUTODIR="$HOME/Workspace/Claude/automation"
LOG="$AUTODIR/pr-dashboard.log"
LOCK="$AUTODIR/.refresh.lock"

log() { print -r -- "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

# --- business-hours guard (09:00–18:59 local) -------------------------------
hour=$((10#$(date +%H)))   # base-10 to avoid octal parse on 08/09
if (( hour < 9 || hour > 18 )); then
  log "skip: ${hour}h is outside 09–18"
  exit 0
fi

# --- single-flight lock: skip if a previous run is still going --------------
if ! mkdir "$LOCK" 2>/dev/null; then
  log "skip: previous run still holding lock ($LOCK)"
  exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

log "start (RunAtLoad or hourly tick)"

claude -p "$(cat "$AUTODIR/pr-dashboard-prompt.md")" \
  --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Write,Edit,Glob,Grep,Skill,Task,mcp__atlassian__getJiraIssue" \
  >> "$LOG" 2>&1
rc=$?

log "done (exit $rc)"
exit 0
