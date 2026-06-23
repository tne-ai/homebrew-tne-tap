#!/usr/bin/env bash
# op-launcher.sh — launchd wrapper that resolves 1Password secrets via op run.
# Retries auth with backoff; exits 0 on give-up so launchd KeepAlive
# (SuccessfulExit=false) does not create an infinite restart cycle.
# Falls back to $OP_LAUNCH_FALLBACK_ENV if 1Password is unavailable.
#
# Installed by brew formula: bin.install "op-launcher.sh" => "op-launcher"
# r-cto-dev155 Principle IV + r-cto-ops92 Pattern B
set -euo pipefail

MAX_RETRIES="${OP_LAUNCH_MAX_RETRIES:-5}"
RETRY_DELAY="${OP_LAUNCH_RETRY_DELAY:-30}"
OP="${OP_BIN:-/opt/homebrew/bin/op}"
# Break-glass: plain env file, gitignored, never committed.
FALLBACK_ENV="${OP_LAUNCH_FALLBACK_ENV:-}"

_try_fallback() {
	if [[ -n "$FALLBACK_ENV" && -f "$FALLBACK_ENV" ]]; then
		echo "op-launcher: 1Password unavailable — sourcing break-glass fallback: $FALLBACK_ENV" >&2
		set -a
		# shellcheck disable=SC1090
		source "$FALLBACK_ENV"
		set +a
		exec "$@"
	fi
	echo "op-launcher: auth failed after $MAX_RETRIES attempts, no fallback — exiting cleanly" >&2
	exit 0  # exit 0: KeepAlive(successful_exit: false) does not restart
}

for i in $(seq 1 "$MAX_RETRIES"); do
	if "$OP" account list --format=json >/dev/null 2>&1; then
		exec "$OP" run "$@"
	fi
	echo "op-launcher: 1Password unavailable (attempt $i/$MAX_RETRIES) — retrying in ${RETRY_DELAY}s" >&2
	sleep "$RETRY_DELAY"
done

_try_fallback "$@"
