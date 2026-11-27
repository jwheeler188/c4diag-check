#!/usr/bin/env bash
# c4diag-run.sh  -  Mac / Linux launcher for the c4diagd check and evidence collection
# Analyst: James Wheeler   Rev 1.7  (recognises the LIKELY PAST INFECTION result)   November 25, 2026
#
# Keep c4diag-check.sh and c4diag-collect.sh in the same folder as this file.
# Needs root SSH access to the controller.
#
#   bash c4diag-run.sh                          # menu
#   bash c4diag-run.sh -i 192.168.1.50          # check only
#   bash c4diag-run.sh -i 192.168.1.50,192.168.1.51 -c auto -o ~/Jobs/Smith
#   bash c4diag-run.sh -i 192.168.1.50 -c always
#   bash c4diag-run.sh -i 192.168.1.50 --collect-only
#   bash c4diag-run.sh -i 192.168.1.50 -k ~/.ssh/c4_ed25519   # key-only SSH
#
#   -i  controller IP(s), comma separated     -u  SSH user (default root)
#   -c  none | auto | always (evidence)       -o  folder for reports (default: current)
#   -k  SSH private key file, or a folder of keys such as the Jailbreak tool's
#       "Keys - DO NOT DELETE" (the key each controller accepts is picked automatically)
#   --collect-only  collect without printing the full check (check still runs first)
#
# The check always runs first. Evidence collection is skipped if the unit looks ARMED.

DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK="$DIR/c4diag-check.sh"
COLLECTSH="$DIR/c4diag-collect.sh"
USER_NAME="root"; KEYFILE=""; OUTDIR="$(pwd)"; COLLECT="none"; COLLECT_ONLY=0; IPS=""

RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; CYN=$'\033[36m'; OFF=$'\033[0m'

while [ $# -gt 0 ]; do
  case "$1" in
    -i) IPS="$2"; shift 2 ;;
    -u) USER_NAME="$2"; shift 2 ;;
    -k) KEYFILE="${2/#\~/$HOME}"; shift 2 ;;
    -o) OUTDIR="$2"; shift 2 ;;
    -c) COLLECT="$2"; shift 2 ;;
    --collect-only) COLLECT_ONLY=1; shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$IPS" ]; then
  echo; echo "${CYN}Control4 c4diagd check  (James Wheeler, rev 1.7)${OFF}"
  echo "Everything here is read-only on the controller. You need root SSH access."; echo
  read -r -p "Controller IP address(es), separated by commas: " IPS
  [ -z "$IPS" ] && { echo "${RED}No IP entered.${OFF}"; exit 1; }
  echo; echo "What would you like to do?"
  echo "  1) Check only (read-only report)"
  echo "  2) Check, and collect evidence if an infection or past infection is found  [recommended]"
  echo "  3) Check, and always collect evidence"
  echo "  4) Collect evidence only (a quick check still runs first and stops if the unit looks armed)"
  read -r -p "Choose 1-4 [2]: " CH
  case "$CH" in 1) COLLECT=none ;; 3) COLLECT=always ;; 4) COLLECT=always; COLLECT_ONLY=1 ;; *) COLLECT=auto ;; esac
  read -r -p "SSH key file or folder (blank = password; for jailbroken units the Jailbreak tool's 'Keys - DO NOT DELETE' folder): " K
  [ -n "$K" ] && KEYFILE="${K/#\~/$HOME}"
  read -r -p "Folder for reports [$OUTDIR]: " O
  [ -n "$O" ] && OUTDIR="${O/#\~/$HOME}"
fi
[ "$COLLECT_ONLY" = 1 ] && [ "$COLLECT" = none ] && COLLECT=always

for f in "$CHECK" $( [ "$COLLECT" != none ] && echo "$COLLECTSH" ); do
  [ -f "$f" ] || { echo "${RED}Cannot find $f. Keep all scripts in the same folder.${OFF}"; exit 1; }
done
command -v ssh >/dev/null && command -v scp >/dev/null || { echo "${RED}ssh/scp not found.${OFF}"; exit 1; }
mkdir -p "$OUTDIR"
[ -n "$KEYFILE" ] && [ ! -e "$KEYFILE" ] && { echo "${RED}Cannot find the key file or folder $KEYFILE.${OFF}"; exit 1; }
# A key FOLDER is allowed: collect private keys, grouped by sub-folder (one per controller MAC)
KEYDIRS=()
if [ -d "$KEYFILE" ]; then
  while IFS= read -r d; do KEYDIRS+=("$d"); done < <(find "$KEYFILE" -type f \( -name 'ssh_host_*_key' -o -name 'id_rsa' -o -name 'id_ed25519' -o -name 'id_ecdsa' \) -exec dirname {} \; | sort -u)
  [ ${#KEYDIRS[@]} -eq 0 ] && { echo "${RED}No private keys (ssh_host_*_key or id_*) found in $KEYFILE.${OFF}"; exit 1; }
  echo "Found keys in ${#KEYDIRS[@]} folder(s) under $KEYFILE."
fi
keyargs() { for f in "$1"/ssh_host_*_key "$1"/id_rsa "$1"/id_ed25519 "$1"/id_ecdsa; do [ -f "$f" ] && printf '%s\n' -i "$f"; done; }

if command -v sha256sum >/dev/null; then HASH="sha256sum"; else HASH="shasum -a 256"; fi
# Copies with Unix line endings, in case the files were edited on Windows
TMPD="$(mktemp -d)"
# Reuse one SSH connection per controller so the password is asked only once
# accept-new: trust a controller's host key the first time without a prompt (a CHANGED key is still refused)
BASEOPT=(-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -o ControlMaster=auto -o "ControlPath=$TMPD/cm-%r@%h-%p" -o ControlPersist=120)
[ -f "$KEYFILE" ] && BASEOPT+=(-i "$KEYFILE" -o IdentitiesOnly=yes)
SSHOPT=("${BASEOPT[@]}")
# Newer OpenSSH (macOS 13+, most current Linux) makes scp use SFTP, which controllers
# do not have ("subsystem request failed"). -O switches back to classic scp if supported.
SCPLEGACY=0; scp 2>&1 | grep -q -- '\[-[0-9A-Za-z]*O[0-9A-Za-z]*\]' && SCPLEGACY=1
tr -d '\r' < "$CHECK" > "$TMPD/c4diag-check.sh"
[ "$COLLECT" != none ] && tr -d '\r' < "$COLLECTSH" > "$TMPD/c4diag-collect.sh"

SUMMARY=""
IFS=', ' read -r -a LIST <<< "$IPS"
for T in "${LIST[@]}"; do
  [ -z "$T" ] && continue
  STAMP="$(date +%Y-%m-%d_%H%M)"
  REPORT="$OUTDIR/c4diag-$T-$STAMP.txt"
  echo; echo "${CYN}=== $T ===${OFF}"

  # Ask the RUNNING sshd which login methods it offers (no login, no password sent).
  # sshd_config can say "no" while an sshd that was never restarted still accepts passwords.
  PROBE="$(ssh -o PreferredAuthentications=none -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$USER_NAME@$T" exit 2>&1)"
  METHODS="$(echo "$PROBE" | sed -n 's/.*Permission denied (\([^)]*\)).*/\1/p' | head -1)"
  AUTHLINE="Running sshd login methods (tested from this computer): ${METHODS:-unknown}"
  if echo "$METHODS" | grep -q password; then AUTHLINE="$AUTHLINE   <-- PASSWORD LOGIN IS LIVE (attacker enabled this; restart sshd after fixing sshd_config)"
  elif echo "$METHODS" | grep -q keyboard-interactive; then AUTHLINE="$AUTHLINE   <-- keyboard-interactive offered (can allow password login; check PasswordAuthentication / KbdInteractiveAuthentication)"; fi
  echo "$AUTHLINE"
  # Jailbroken controllers usually accept key login only. Without a key every login would
  # fail with a vague "lost connection", so stop here and say what to do.
  if [ -z "$KEYFILE" ] && [ -n "$METHODS" ] && ! echo "$METHODS" | grep -qE 'password|keyboard-interactive'; then
    echo "${RED}$T only accepts key login (no passwords). Run again with -k <private key file>, or enter it in the menu.${OFF}"
    echo "${YEL}Jailbroken with the Control4 Jailbreak tool? Give its 'Keys - DO NOT DELETE' folder (or a key file inside it) with -k.${OFF}"
    SUMMARY+="$T | NOT CHECKED (key login required)"$'\n'; continue
  fi

  # Key folder: find the key set this controller accepts (BatchMode = no prompts)
  SSHOPT=("${BASEOPT[@]}")
  if [ ${#KEYDIRS[@]} -gt 0 ]; then
    CHOSEN=""; LASTERR=""
    for D in "${KEYDIRS[@]}"; do
      KA=(); while IFS= read -r a; do KA+=("$a"); done < <(keyargs "$D")
      LASTERR="$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o IdentitiesOnly=yes "${KA[@]}" "$USER_NAME@$T" exit 2>&1)" && { CHOSEN="$D"; break; }
    done
    if [ -z "$CHOSEN" ]; then
      echo "${RED}None of the keys under $KEYFILE were accepted by $T.${OFF}"; [ -n "$LASTERR" ] && echo "ssh said: $LASTERR"
      echo "Key folders tried: $(for D in "${KEYDIRS[@]}"; do basename "$D"; done | tr '\n' ' ')"
      echo "${YEL}Each sub-folder is one controller (named by MAC). If this controller's MAC isn't there, run the Jailbreak tool's 'SSH Access' mode on it first.${OFF}"
      SUMMARY+="$T | NOT CHECKED (no key accepted)"$'\n'; continue
    fi
    echo "Key accepted: $CHOSEN"
    KA=(); while IFS= read -r a; do KA+=("$a"); done < <(keyargs "$CHOSEN"); SSHOPT+=(-o IdentitiesOnly=yes "${KA[@]}")
  fi
  SCPOPT=("${SSHOPT[@]}"); [ $SCPLEGACY = 1 ] && SCPOPT+=(-O)

  if ! scp "${SCPOPT[@]}" "$TMPD/c4diag-check.sh" "$USER_NAME@$T:/tmp/c4diag-check.sh"; then
    echo "${RED}Could not copy the script to $T (check the IP, network and SSH access).${OFF}"
    SUMMARY+="$T | NOT CHECKED (copy failed)"$'\n'; continue
  fi
  ssh "${SSHOPT[@]}" "$USER_NAME@$T" "sh /tmp/c4diag-check.sh; rm -f /tmp/c4diag-check.sh" > "$REPORT" 2>&1
  if [ $? -eq 255 ]; then
    cat "$REPORT"; rm -f "$REPORT"
    echo "${RED}Could not log in to $T to run the check. The copy in /tmp was left on the controller.${OFF}"
    SUMMARY+="$T | NOT CHECKED (login failed)"$'\n'; continue
  fi
  { echo "$AUTHLINE"; echo; cat "$REPORT"; } > "$REPORT.tmp" && mv "$REPORT.tmp" "$REPORT"
  [ "$COLLECT_ONLY" = 1 ] || cat "$REPORT"

  RESULT="UNKNOWN (see report)"; COL="$YEL"
  if   grep -q "ARMED / LOCKED INDICATORS FOUND" "$REPORT"; then RESULT="ARMED - do not reboot, escalate to Control4"; COL="$RED"
  elif grep -q "INFECTED (staged)" "$REPORT"; then RESULT="INFECTED (staged)"; COL="$RED"
  elif grep -q "PREVIOUSLY INFECTED, NOW CLEAN" "$REPORT"; then RESULT="PREVIOUSLY INFECTED, NOW CLEAN"; COL="$YEL"
  elif grep -q "LIKELY PAST INFECTION" "$REPORT"; then RESULT="LIKELY PAST INFECTION (masked service only)"; COL="$YEL"
  elif grep -q "POSSIBLE PAST INFECTION" "$REPORT"; then RESULT="POSSIBLE PAST INFECTION (timestamps only)"; COL="$YEL"
  elif grep -q "NO INDICATORS FOUND" "$REPORT"; then RESULT="NO INDICATORS FOUND"; COL="$GRN"; fi
  echo; echo "Result for $T: ${COL}${RESULT}${OFF}"; echo "Saved to $REPORT"

  EVID=""
  DO=0
  [ "$COLLECT" = always ] && DO=1
  [ "$COLLECT" = auto ] && echo "$RESULT" | grep -q INFECT && DO=1
  if [ $DO = 1 ] && echo "$RESULT" | grep -q '^ARMED'; then
    echo "${RED}Evidence collection skipped: the unit shows armed indicators. Leave it untouched and escalate to Control4.${OFF}"; DO=0
  fi
  if [ $DO = 1 ]; then
    echo "${CYN}Collecting evidence from $T ...${OFF}"
    if ! scp "${SCPOPT[@]}" "$TMPD/c4diag-collect.sh" "$USER_NAME@$T:/tmp/c4diag-collect.sh"; then
      echo "${RED}Could not copy the collect script to $T. No evidence collected.${OFF}"
      SUMMARY+="$T | $RESULT | $REPORT"$'\n'; continue
    fi
    OUT="$(ssh "${SSHOPT[@]}" "$USER_NAME@$T" "sh /tmp/c4diag-collect.sh; rm -f /tmp/c4diag-collect.sh" 2>&1)"
    ARCH="$(echo "$OUT" | grep '^ARCHIVE=' | tail -1 | cut -d= -f2-)"
    if [ -n "$ARCH" ] && scp "${SCPOPT[@]}" "$USER_NAME@$T:$ARCH" "$OUTDIR/"; then
      LOCAL="$OUTDIR/$(basename "$ARCH")"
      ssh "${SSHOPT[@]}" "$USER_NAME@$T" "rm -f $ARCH" >/dev/null 2>&1
      { echo "$OUT" | grep -E '^[0-9a-f]{64} ' | sed 's/^/Controller-side hash: /'
        echo "PC-side SHA-256:      $($HASH "$LOCAL" | cut -d' ' -f1)"; } > "$LOCAL.sha256.txt"
      echo "${GRN}Evidence saved to $LOCAL${OFF}"
      echo "Hashes recorded in $LOCAL.sha256.txt"
      echo "${YEL}Do not extract or run this archive on your computer.${OFF}"
      EVID="$LOCAL"
    else
      echo "${RED}Evidence collection failed. Output:${OFF}"; echo "$OUT"
    fi
  fi
  SUMMARY+="$T | $RESULT | $REPORT${EVID:+ | $EVID}"$'\n'
done

for T in "${LIST[@]}"; do ssh -O exit -o ControlPath="$TMPD/cm-%r@%h-%p" "$USER_NAME@$T" >/dev/null 2>&1; done
rm -rf "$TMPD"
echo; echo "${CYN}=== Summary ===${OFF}"; printf '%s' "$SUMMARY"
