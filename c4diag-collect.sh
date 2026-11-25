#!/bin/sh
# c4diag-collect.sh  -  gather c4diagd / c4hijack evidence into one archive for Control4
# Analyst: James Wheeler   Rev 1.2   November 25, 2026
#
# Run as root over SSH:   sh c4diag-collect.sh
# Only READS from the system. It writes a working folder and a .tar.gz under /tmp
# and prints the archive path on the last line as:  ARCHIVE=/tmp/....tar.gz
# The archive may contain the live malware binary. Do not extract or run it on a PC.
# Do not run this on an ARMED unit's watchdog path: it does not stop or kill anything.

TS=$(date -u +%Y%m%dT%H%M%SZ)
H=$(hostname 2>/dev/null || echo controller)
NAME="c4diag-evidence-$H-$TS"
OUT="/tmp/$NAME"
F="$OUT/files"
MAXSIZE=20971520   # skip any single file over 20 MB
# /tmp is usually RAM on controllers. Filling it can crash Director, so stop early.
FREE_KB=$(df -k /tmp 2>/dev/null | awk 'NR==2 {print $4}')
[ -z "$FREE_KB" ] && FREE_KB=307200   # df unavailable: assume 300 MB
if [ -n "$FREE_KB" ] && [ "$FREE_KB" -lt 102400 ]; then
  echo "Not enough free space in /tmp (${FREE_KB} KB, need 100 MB). Nothing collected."
  exit 1
fi
mkdir -p "$F" "$OUT/cmd"

grab() {  # copy a file or folder, keeping its path and timestamps
  for p in "$@"; do
    [ -e "$p" ] || continue
    if [ -f "$p" ]; then
      SZ=$(wc -c < "$p" 2>/dev/null || echo 0)
      if [ "$SZ" -gt "$MAXSIZE" ]; then echo "skipped (too large): $p ($SZ bytes)" >> "$OUT/skipped.txt"; continue; fi
    fi
    USED_KB=$(du -sk "$OUT" 2>/dev/null | cut -f1)
    if [ "${USED_KB:-0}" -gt $(( FREE_KB / 3 )) ] 2>/dev/null; then echo "skipped (space limit): $p" >> "$OUT/skipped.txt"; continue; fi
    mkdir -p "$F$(dirname "$p")"
    cp -pR "$p" "$F$(dirname "$p")/" 2>>"$OUT/copy-errors.txt"
  done
}
run() {  # save a command's output
  NAME_OUT="$1"; shift
  ( "$@" ) > "$OUT/cmd/$NAME_OUT.txt" 2>&1
}

# Kit files
grab /usr/local/bin/c4diagd /usr/local/bin/c4diagd.cfg.json \
     /etc/systemd/system/c4diagd.service \
     /etc/systemd/system/multi-user.target.wants/c4diagd.service \
     /opt/.c4diag /var/log/c4diagd.log /tmp/c4diag-setup

# Startup, SSH and cleanup evidence
grab /etc/inittab /etc/ssh/sshd_config /etc/ssh/ssh_c4_ca.pub /etc/ssh/root_principals \
     /etc/ssh/revoked-keys.krl /root/.ssh/authorized_keys /etc/network/interfaces \
     /mnt/internal/rms_maint.log /mnt/internal/fix-755444.sh
for l in /var/log/daemon.log* /var/log/auth.log* /var/log/messages* /var/log/secure*; do grab "$l"; done

# Recovery partition (mounted read-only if it is not already mounted)
REC=""
if mountpoint -q /recovery 2>/dev/null; then REC=/recovery
elif [ -b /dev/mmcblk0p2 ]; then
  mkdir -p /tmp/c4col_rec && { mount -o ro,noload /dev/mmcblk0p2 /tmp/c4col_rec 2>/dev/null || mount -o ro /dev/mmcblk0p2 /tmp/c4col_rec 2>/dev/null; } && REC=/tmp/c4col_rec
fi
if [ -n "$REC" ]; then
  mkdir -p "$F/recovery-partition"
  [ -f "$REC/recovery.scr" ] && cp -p "$REC/recovery.scr" "$F/recovery-partition/"
  [ -d "$REC/c4diag" ] && cp -pR "$REC/c4diag" "$F/recovery-partition/"
  ls -la "$REC" > "$OUT/cmd/recovery-partition-listing.txt" 2>&1
  [ "$REC" = /tmp/c4col_rec ] && umount /tmp/c4col_rec 2>/dev/null && rmdir /tmp/c4col_rec 2>/dev/null
fi

# System state
run uname uname -a
run date-utc date -u
run uptime uptime
run ps sh -c 'ps aux 2>/dev/null || ps'
run connections sh -c 'ss -tnp 2>/dev/null || netstat -tnp 2>/dev/null || netstat -tn'
run ip-addr sh -c 'ip addr 2>/dev/null || ifconfig -a'
run crontab crontab -l
run last sh -c 'last 2>/dev/null | head -100'
run dpkg-patch sh -c 'dpkg -l 2>/dev/null | grep -i patch'
run systemctl-c4diagd sh -c 'systemctl status c4diagd 2>&1; systemctl list-unit-files 2>/dev/null | grep -i masked'
run sysman sh -c 'sysman list 2>/dev/null || ls /etc/sysman.d'
run c4diag-log-lines sh -c 'for f in /var/log/daemon.log* /var/log/messages*; do [ -f "$f" ] || continue; case "$f" in *.gz) zcat "$f";; *) cat "$f";; esac; done 2>/dev/null | grep -i c4diag'
run usr-local-bin sh -c 'ls -la /usr/local/bin; ls -la /opt'
run recent-changes sh -c 'touch -d 2026-11-15 /tmp/.c4col_ref && find /etc /usr/local /opt /root -xdev -type f -newer /tmp/.c4col_ref 2>/dev/null | head -2000; rm -f /tmp/.c4col_ref'
run api-cert sh -c 'for c in /opt/control4/etc/ssl/certs/api.pem /etc/openvpn/api.pem; do [ -e "$c" ] && openssl x509 -in "$c" -noout -subject -issuer -dates; done'

# Manifest with hashes
{
  echo "c4diagd evidence archive"
  echo "Host:      $H"
  echo "Collected: $TS (UTC)"
  echo "Collector: c4diag-collect.sh rev 1.2"
  echo "WARNING:   files/usr/local/bin/c4diagd (if present) is live malware. Do not run it."
  echo
  echo "SHA-256 of collected files:"
  find "$OUT" -type f ! -name MANIFEST.txt -exec sha256sum {} \; | sed "s#$OUT/##"
} > "$OUT/MANIFEST.txt"

tar -czf "$OUT.tar.gz" -C /tmp "$NAME"; rm -rf "$OUT"
sha256sum "$OUT.tar.gz"
echo "ARCHIVE=$OUT.tar.gz"
