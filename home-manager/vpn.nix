{ config, pkgs, ... }:

# openfortivpn SAML VPN helpers (vpn-connect / vpn-disconnect / vpn-watchdog).
# eeze  -> v1-mtb.tain.com:8443   (same FortiGate cert as the legacy 80.85.106.18)
# aws   -> fg01.eeze.com:10443
# Requires openfortivpn on PATH (installed via Homebrew: /opt/homebrew/bin/openfortivpn).
#
# Every privileged call below is issued by ABSOLUTE path. That is not style: the matching
# NOPASSWD rules live in darwin/darwin.nix and sudoers matches on the fully-qualified
# path, so a bare `sudo openfortivpn` would resolve through PATH and miss the rule.
let
  homeDir = config.home.homeDirectory;

  # State files. The name/desired split is the whole basis of the watchdog:
  #   .vpn-name     — which profile is CURRENTLY up; cleared on every teardown.
  #   .vpn-desired  — which profile you WANT up; survives teardown, so the watchdog can
  #                   tell "you ran vpn-disconnect" from "the tunnel dropped". Only a
  #                   user-invoked vpn-disconnect clears it.
  pidFile = "${homeDir}/.vpn.pid";
  dnsFile = "${homeDir}/.vpn-original-dns";
  nameFile = "${homeDir}/.vpn-name";
  desiredFile = "${homeDir}/.vpn-desired";
  attemptFile = "${homeDir}/.vpn-attempts";
  nextFile = "${homeDir}/.vpn-next-attempt";
  watchdogLog = "${homeDir}/.vpn-watchdog.log";

  vpnDisconnect = pkgs.writeShellScriptBin "vpn-disconnect" ''
    set -euo pipefail

    NET_SERVICE="Wi-Fi"

    # --internal: teardown only, leave the reconnect intent alone. vpn-connect uses this
    # to clean up before dialling; a bare vpn-disconnect is the user saying "stay down".
    KEEP_DESIRED=0
    [[ "''${1:-}" == "--internal" ]] && KEEP_DESIRED=1

    # Kill the actual openfortivpn process
    sudo /usr/bin/pkill -f openfortivpn 2>/dev/null | tr '\r' '\n' || true

    # Also kill any leftover pppd
    sudo /usr/bin/pkill -f pppd 2>/dev/null | tr '\r' '\n' || true

    rm -f "${pidFile}"

    # Restore DNS — always attempt, even if DNS_FILE is missing.
    # A timed-out VPN leaves DNS pointing at unreachable VPN servers,
    # so falling back to "empty" (DHCP-provided DNS) is safer than doing nothing.
    if [[ -f "${dnsFile}" ]]; then
      ORIGINAL_DNS=$(tr '\n' ' ' < "${dnsFile}")
      if [[ "$ORIGINAL_DNS" == *"any DNS"* ]] || [[ -z "$ORIGINAL_DNS" ]]; then
        sudo /usr/sbin/networksetup -setdnsservers "$NET_SERVICE" empty
      else
        sudo /usr/sbin/networksetup -setdnsservers "$NET_SERVICE" $ORIGINAL_DNS
      fi
      rm -f "${dnsFile}"
    else
      # No saved DNS — reset to DHCP defaults
      sudo /usr/sbin/networksetup -setdnsservers "$NET_SERVICE" empty
    fi

    sudo /usr/bin/dscacheutil -flushcache
    sudo /usr/bin/killall -HUP mDNSResponder 2>/dev/null || true

    rm -f "${nameFile}"

    if [[ $KEEP_DESIRED -eq 0 ]]; then
      rm -f "${desiredFile}" "${attemptFile}" "${nextFile}"
      echo
      echo "VPN disconnected. DNS restored. Auto-reconnect off."
    fi
  '';

  vpnConnect = pkgs.writeShellScriptBin "vpn-connect" ''
    set -euo pipefail

    # launchd hands the watchdog a bare PATH (/usr/bin:/bin:/usr/sbin:/sbin), which has
    # no openfortivpn. Set it explicitly so this behaves the same from a shell and from
    # the agent.
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/run/current-system/sw/bin:$PATH"

    NET_SERVICE="Wi-Fi"

    usage() {
      echo "Usage: vpn-connect <eeze|aws>"
      exit 1
    }

    [[ $# -lt 1 ]] && usage

    case "$1" in
      eeze)
        VPN_HOST="v1-mtb.tain.com:8443"
        TRUSTED_CERT="b542a3b331b9723031cc69768e3c2bad1bfa73c1f42770d1480a03c4a4a8056e"
        ;;
      aws)
        VPN_HOST="fg01.eeze.com:10443"
        TRUSTED_CERT="2ddce84a1b014415f6ac5b3c0db1ac437b93785aca8520dbd64aa742e5c402db"
        ;;
      *)
        usage
        ;;
    esac

    VPN_NAME="$1"

    # Record intent BEFORE dialling. If the first attempt fails the watchdog still knows
    # what you were reaching for and can retry.
    echo "$VPN_NAME" > "${desiredFile}"

    # Clean up any existing VPN connection (live or stale from a timeout)
    if [[ -f "${pidFile}" ]] || [[ -f "${dnsFile}" ]] || pgrep -f openfortivpn &>/dev/null; then
      CURRENT=$(cat "${nameFile}" 2>/dev/null || echo "unknown")
      echo "Cleaning up previous VPN session ($CURRENT)..."
      ${vpnDisconnect}/bin/vpn-disconnect --internal
    fi

    # Capture original DNS
    networksetup -getdnsservers "$NET_SERVICE" 2>/dev/null > "${dnsFile}"

    TMP_LOG=$(mktemp)

    # Bounded waits. The watchdog runs this unattended under launchd, where the original
    # unbounded `while ! grep` would wedge the agent forever instead of failing and
    # letting the backoff retry.
    wait_for() {
      pattern="$1"
      timeout="$2"
      deadline=$(( $(date +%s) + timeout ))
      while ! grep -q "$pattern" "$TMP_LOG"; do
        if [[ "$(date +%s)" -ge "$deadline" ]]; then
          echo "vpn-connect: timed out after ''${timeout}s waiting for '$pattern'" >&2
          ${vpnDisconnect}/bin/vpn-disconnect --internal >/dev/null 2>&1 || true
          rm -f "$TMP_LOG"
          exit 1
        fi
        sleep 0.5
      done
    }

    sudo /opt/homebrew/bin/openfortivpn "$VPN_HOST" \
      --saml-login \
      --trusted-cert "$TRUSTED_CERT" \
      --pppd-accept-remote=0 \
      2>&1 | tee "$TMP_LOG" &

    # Wait until SAML URL appears
    wait_for "Authenticate at" 30

    URL=$(grep "Authenticate at" "$TMP_LOG" | sed -E "s/.*'(.*)'.*/\1/")
    open "$URL"

    # Wait for tunnel. Generous: if the IdP session lapsed this is a human typing a
    # password into the browser tab we just opened.
    wait_for "Tunnel is up and running" 120

    # Parse and set DNS
    VPN_DNS=$(grep "Got addresses" "$TMP_LOG" | sed -E 's/.*ns \[([^]]+)\].*/\1/' | tr -d ' ' | tr ',' ' ')
    ORIGINAL_DNS=$(tr '\n' ' ' < "${dnsFile}")

    if [[ -n "$VPN_DNS" ]]; then
      if [[ "$ORIGINAL_DNS" == *"any DNS"* ]] || [[ -z "$ORIGINAL_DNS" ]]; then
        sudo /usr/sbin/networksetup -setdnsservers "$NET_SERVICE" $VPN_DNS
      else
        sudo /usr/sbin/networksetup -setdnsservers "$NET_SERVICE" $VPN_DNS $ORIGINAL_DNS
      fi
      sudo /usr/bin/dscacheutil -flushcache
      sudo /usr/bin/killall -HUP mDNSResponder 2>/dev/null || true
    fi

    VPN_PID=$(pgrep -f openfortivpn | head -1)
    echo "$VPN_PID" > "${pidFile}"
    echo "$VPN_NAME" > "${nameFile}"

    # Clear any backoff the watchdog accumulated — including a given-up state, so a
    # manual reconnect re-arms auto-reconnect.
    rm -f "${attemptFile}" "${nextFile}"

    echo "VPN connected to $VPN_NAME (PID: $VPN_PID). Running in background."
    rm -f "$TMP_LOG"
  '';

  # Reconnect watcher. Fires on a 60s tick and on network change; reconnects the last
  # profile until you run vpn-disconnect.
  #
  # It cannot be fully silent: --saml-login must open a browser. With a live IdP session
  # a tab flashes and the tunnel is back in ~2s; with a lapsed one the login page waits
  # for you. Hence the capped retry — an unbounded loop would stack browser tabs all
  # afternoon while you are away from the machine.
  maxAttempts = 15;

  vpnWatchdog = pkgs.writeShellScriptBin "vpn-watchdog" ''
    set -uo pipefail
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/run/current-system/sw/bin:$PATH"

    log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

    # No intent recorded -> you are deliberately disconnected. Do nothing.
    [[ -f "${desiredFile}" ]] || exit 0
    PROFILE=$(cat "${desiredFile}")
    [[ -n "$PROFILE" ]] || exit 0

    # Healthy = the client is running AND the tunnel interface exists. The process alone
    # is not enough: pppd can die and leave a parent that never notices.
    if pgrep -f openfortivpn >/dev/null 2>&1 && /sbin/ifconfig ppp0 >/dev/null 2>&1; then
      # Recovered (or never left) — clear the backoff.
      [[ -f "${attemptFile}" ]] && log "tunnel healthy again ($PROFILE); resetting backoff"
      rm -f "${attemptFile}" "${nextFile}"
      exit 0
    fi

    NOW=$(date +%s)

    # Respect the backoff window.
    if [[ -f "${nextFile}" ]] && [[ "$NOW" -lt "$(cat "${nextFile}")" ]]; then
      exit 0
    fi

    ATTEMPTS=$(cat "${attemptFile}" 2>/dev/null || echo 0)

    if [[ "$ATTEMPTS" -ge ${toString maxAttempts} ]]; then
      exit 0   # already gave up and notified; stay quiet until vpn-connect/-disconnect
    fi

    ATTEMPTS=$((ATTEMPTS + 1))
    echo "$ATTEMPTS" > "${attemptFile}"

    # 1m, 2m, 4m, 8m, then every 10m — ~2h of coverage across ${toString maxAttempts} attempts.
    case "$ATTEMPTS" in
      1) DELAY=60  ;;
      2) DELAY=120 ;;
      3) DELAY=240 ;;
      4) DELAY=480 ;;
      *) DELAY=600 ;;
    esac
    echo $((NOW + DELAY)) > "${nextFile}"

    log "tunnel down; reconnecting '$PROFILE' (attempt $ATTEMPTS/${toString maxAttempts})"

    if ${vpnConnect}/bin/vpn-connect "$PROFILE"; then
      log "reconnected to '$PROFILE'"
      exit 0
    fi

    log "reconnect attempt $ATTEMPTS/${toString maxAttempts} failed; next try in ''${DELAY}s"

    if [[ "$ATTEMPTS" -ge ${toString maxAttempts} ]]; then
      log "giving up after ${toString maxAttempts} attempts; run vpn-connect $PROFILE to re-arm"
      /usr/bin/osascript -e "display notification \"Gave up reconnecting '$PROFILE' after ${toString maxAttempts} attempts. Run vpn-connect $PROFILE to re-arm.\" with title \"VPN auto-reconnect\"" >/dev/null 2>&1 || true
    fi
  '';
in
{
  home.packages = [ vpnConnect vpnDisconnect vpnWatchdog ];

  launchd.agents.vpn-watchdog = {
    enable = true;
    config = {
      ProgramArguments = [ "${vpnWatchdog}/bin/vpn-watchdog" ];
      StartInterval = 60;
      # /etc/resolv.conf churns on wake and on Wi-Fi switch, so recovery is immediate
      # rather than up to a tick late. Our own DNS writes also trip it; the check is
      # idempotent and costs nothing.
      WatchPaths = [ "/etc/resolv.conf" ];
      RunAtLoad = false;
      # Without this launchd reaps the openfortivpn that vpn-connect deliberately leaves
      # running when the watchdog exits, and the tunnel dies the moment we fix it.
      AbandonProcessGroup = true;
      StandardOutPath = watchdogLog;
      StandardErrorPath = watchdogLog;
    };
  };
}
