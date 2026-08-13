#!/usr/bin/env bash
# Open a browser at the login page when the network we joined wants a
# click-through (hotel, airport, train wifi).
#
# NetworkManager does the detecting already: its connectivity check fetches a
# known plain-HTTP URL, a captive gateway rewrites the reply, and NM reports
# connectivity `portal` (see /etc/NetworkManager/conf.d/20-connectivity.conf).
# Nothing on niri reacts to that state — GNOME Shell has the handler built in, a
# bare compositor doesn't. This is that handler.
#
# Usage:
#   captive-portal-watch.sh          daemon; run by captive-portal.service
#   captive-portal-watch.sh --now    open the portal page now, whatever NM thinks
#
# The manual form is the escape hatch for the case NM misses: a gateway that
# passes the connectivity check but still gates real traffic.

set -euo pipefail

# Where to point the browser. Two hard constraints:
#   * plain HTTP — an HTTPS request can't be intercepted without a cert warning
#   * not HSTS-preloaded — or the browser rewrites it to HTTPS before the
#     gateway ever sees the request
# The second rules out reusing NM's own check URL: archlinux.org is in the
# preload list. neverssl.com exists precisely for this job and sends no-cache
# headers, so a stale copy can't satisfy the request either.
PORTAL_URL="${CAPTIVE_PORTAL_URL:-http://neverssl.com}"

# nmcli translates state names; force C so the string compares below hold on a
# non-English locale.
export LC_ALL=C

log() { printf 'captive-portal: %s\n' "$1"; }

connectivity() {
    nmcli -t -f CONNECTIVITY general status 2>/dev/null || echo unknown
}

open_portal() {
    log "connectivity is 'portal' — opening $PORTAL_URL"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send --app-name=Network --icon=network-wireless-acquiring \
            "Wi-Fi needs a login" "Opening the network's sign-in page." || true
    fi

    # A private window keeps the portal's cookies and its (often junk)
    # redirect history out of the everyday profile. Zen is Firefox-derived, so
    # this lands in the already-running instance instead of starting a second
    # one. Backgrounded and detached — the watcher has to keep running, and it
    # must not die with the browser.
    if command -v zen-browser >/dev/null 2>&1; then
        setsid zen-browser --private-window "$PORTAL_URL" >/dev/null 2>&1 &
    elif command -v xdg-open >/dev/null 2>&1; then
        setsid xdg-open "$PORTAL_URL" >/dev/null 2>&1 &
    else
        log "no browser found — open $PORTAL_URL by hand"
        return 0
    fi
}

if [ "${1:-}" = "--now" ]; then
    open_portal
    exit 0
fi

state=$(connectivity)
log "starting; connectivity is '$state'"
if [ "$state" = portal ]; then
    open_portal
fi

# `nmcli monitor` prints a line on every connection/state change but its wording
# is localised and not a stable interface, so treat each line purely as a wake-up
# and re-read the state properly. Acting only on a *transition* into `portal`
# means a flapping link can't reopen the browser on every check.
#
# monitor exits when NetworkManager itself restarts; the service is Restart=always.
while read -r _; do
    new=$(connectivity)
    [ "$new" = "$state" ] && continue
    log "connectivity: $state -> $new"
    state=$new
    if [ "$new" = portal ]; then
        open_portal
    fi
done < <(nmcli monitor)
