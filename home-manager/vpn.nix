{ pkgs, ... }:

# openfortivpn SAML VPN helpers (vpn-connect / vpn-disconnect).
# eeze  -> v1-mtb.tain.com:8443   (same FortiGate cert as the legacy 80.85.106.18)
# aws   -> fg01.eeze.com:10443
# Requires openfortivpn on PATH (installed via Homebrew: /opt/homebrew/bin/openfortivpn).
{
  home.packages = [
    (pkgs.writeShellScriptBin "vpn-connect" ''
      set -euo pipefail

      NET_SERVICE="Wi-Fi"
      PID_FILE="$HOME/.vpn.pid"
      DNS_FILE="$HOME/.vpn-original-dns"
      VPN_NAME_FILE="$HOME/.vpn-name"

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

      # Clean up any existing VPN connection (live or stale from a timeout)
      if [[ -f "$PID_FILE" ]] || [[ -f "$DNS_FILE" ]] || pgrep -f openfortivpn &>/dev/null; then
        CURRENT=$(cat "$VPN_NAME_FILE" 2>/dev/null || echo "unknown")
        echo "Cleaning up previous VPN session ($CURRENT)..."
        vpn-disconnect
      fi

      # Capture original DNS
      networksetup -getdnsservers "$NET_SERVICE" 2>/dev/null > "$DNS_FILE"

      TMP_LOG=$(mktemp)

      sudo openfortivpn "$VPN_HOST" \
        --saml-login \
        --trusted-cert "$TRUSTED_CERT" \
        --pppd-accept-remote=0 \
        2>&1 | tee "$TMP_LOG" &

      # Wait until SAML URL appears
      while ! grep -q "Authenticate at" "$TMP_LOG"; do
        sleep 0.5
      done

      URL=$(grep "Authenticate at" "$TMP_LOG" | sed -E "s/.*'(.*)'.*/\1/")
      open "$URL"

      # Wait for tunnel
      while ! grep -q "Tunnel is up and running" "$TMP_LOG"; do
        sleep 0.5
      done

      # Parse and set DNS
      VPN_DNS=$(grep "Got addresses" "$TMP_LOG" | sed -E 's/.*ns \[([^]]+)\].*/\1/' | tr -d ' ' | tr ',' ' ')
      ORIGINAL_DNS=$(tr '\n' ' ' < "$DNS_FILE")

      if [[ -n "$VPN_DNS" ]]; then
        if [[ "$ORIGINAL_DNS" == *"any DNS"* ]] || [[ -z "$ORIGINAL_DNS" ]]; then
          sudo networksetup -setdnsservers "$NET_SERVICE" $VPN_DNS
        else
          sudo networksetup -setdnsservers "$NET_SERVICE" $VPN_DNS $ORIGINAL_DNS
        fi
        sudo dscacheutil -flushcache
        sudo killall -HUP mDNSResponder 2>/dev/null || true
      fi

      VPN_PID=$(pgrep -f openfortivpn | head -1)
      echo "$VPN_PID" > "$PID_FILE"
      echo "$VPN_NAME" > "$VPN_NAME_FILE"
      echo "VPN connected to $VPN_NAME (PID: $VPN_PID). Running in background."
      rm -f "$TMP_LOG"
    '')

    (pkgs.writeShellScriptBin "vpn-disconnect" ''
      set -euo pipefail

      NET_SERVICE="Wi-Fi"
      PID_FILE="$HOME/.vpn.pid"
      DNS_FILE="$HOME/.vpn-original-dns"
      VPN_NAME_FILE="$HOME/.vpn-name"

      # Kill the actual openfortivpn process
      sudo pkill -f openfortivpn 2>/dev/null | tr '\r' '\n' || true

      # Also kill any leftover pppd
      sudo pkill -f pppd 2>/dev/null | tr '\r' '\n' || true

      rm -f "$PID_FILE"

      # Restore DNS — always attempt, even if DNS_FILE is missing.
      # A timed-out VPN leaves DNS pointing at unreachable VPN servers,
      # so falling back to "empty" (DHCP-provided DNS) is safer than doing nothing.
      if [[ -f "$DNS_FILE" ]]; then
        ORIGINAL_DNS=$(tr '\n' ' ' < "$DNS_FILE")
        if [[ "$ORIGINAL_DNS" == *"any DNS"* ]] || [[ -z "$ORIGINAL_DNS" ]]; then
          sudo networksetup -setdnsservers "$NET_SERVICE" empty
        else
          sudo networksetup -setdnsservers "$NET_SERVICE" $ORIGINAL_DNS
        fi
        rm -f "$DNS_FILE"
      else
        # No saved DNS — reset to DHCP defaults
        sudo networksetup -setdnsservers "$NET_SERVICE" empty
      fi

      sudo dscacheutil -flushcache
      sudo killall -HUP mDNSResponder 2>/dev/null || true

      rm -f "$VPN_NAME_FILE"

      echo
      echo "VPN disconnected. DNS restored."
    '')
  ];
}
