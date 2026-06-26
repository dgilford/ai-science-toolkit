#!/bin/zsh
# Install the window-warmup LaunchAgent (Tier 1, primary). No sudo required.
# Deploys warmup.sh, renders the plist template, and (re)loads the agent.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST_DIR="${HOME}/.claude/window-warmup"
SCRIPT_DEST="${DEST_DIR}/warmup.sh"
LOG="${HOME}/.claude/window-warmup.log"
LABEL="com.dgilford.window-warmup"
PLIST_DEST="${HOME}/Library/LaunchAgents/${LABEL}.plist"

mkdir -p "${DEST_DIR}" "${HOME}/Library/LaunchAgents"

install -m 0755 "${SRC_DIR}/warmup.sh" "${SCRIPT_DEST}"

sed -e "s|__SCRIPT__|${SCRIPT_DEST}|g" -e "s|__LOG__|${LOG}|g" \
    "${SRC_DIR}/${LABEL}.plist.template" > "${PLIST_DEST}"

# Reload cleanly (bootout is a no-op if not loaded).
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "${PLIST_DEST}"

echo "Installed and loaded ${LABEL}."
echo "  script: ${SCRIPT_DEST}"
echo "  plist:  ${PLIST_DEST}"
echo "  log:    ${LOG}"
echo
echo "Test now:   launchctl kickstart -k gui/$(id -u)/${LABEL} && sleep 5 && tail -n 5 ${LOG}"
echo
echo "Guarantee the 5am wake-from-sleep (recommended belt; WakeSystem alone is unreliable):"
echo "  sudo pmset repeat wake MTWRF 04:58:00     # then confirm with: pmset -g sched"
echo
echo "Tier 2 (fallback) is manual: set up cron-job.org -> workflow_dispatch (see README.md)."
