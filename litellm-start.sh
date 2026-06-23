#!/usr/bin/env bash
# litellm-start.sh — start LiteLLM with secrets from environment.
# r-coo92 Principle VIII + r-cto-dev145: scripts NEVER resolve secrets.
# Secrets must be pre-resolved by .envrc (direnv) before this script runs.
# Re-run litellm-install.sh to regenerate if api-keys.yaml changes.
set -euo pipefail
SCRIPT_DIR=${SCRIPT_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
LITELLM_PORT="${LITELLM_PORT:-4000}"
LITELLM_CFG="${LITELLM_CFG:-$HOME/.config/litellm/config.yaml}"
LITELLM_DB="${LITELLM_DB:-litellm}"
MLFLOW_PORT="${MLFLOW_PORT:-5001}"
LOG="${TNE_LOG_DIR:-$HOME/ws/logs}/litellm.log"
mkdir -p "$(dirname "$LOG")"

# Non-secret runtime config
export DATABASE_URL="postgresql://${USER}@localhost/${LITELLM_DB}"
export MLFLOW_TRACKING_URI="http://localhost:${MLFLOW_PORT}"
export MLFLOW_EXPERIMENT_NAME="ai-usage"

# Required secrets — must be pre-resolved by .envrc/launchd, never by this script.
# r-coo92 Principle VIII + r-cto-dev145 Law I: fail loud on missing or unresolved op:// literals.
_REQUIRED_SECRETS=(
	MINIMAX_API_KEY
	MINIMAX_PLAN_KEY
	Z_AI_PLAN_KEY
	MOONSHOT_API_KEY
	DEEPSEEK_API_KEY
	OPENROUTER_API_KEY
	LITELLM_MASTER_KEY
	SAMBANOVA_API_KEY
	CLIPROXYAPI_KEY
	LM_STUDIO_API_TOKEN
)
for _var in "${_REQUIRED_SECRETS[@]}"; do
	_val="${!_var:-}"
	[[ -z "$_val" ]] && {
		echo "ERROR: $_var is unset — source .envrc (r-coo92 Principle VIII)" >&2
		exit 1
	}
	[[ "$_val" == op://* ]] && {
		echo "ERROR: $_var unresolved op:// literal — direnv did not run (r-cto-dev145)" >&2
		exit 1
	}
done
unset _var _val _REQUIRED_SECRETS

# Prisma self-heal — regenerate if native query engine binary missing from cache.
# prisma --version succeeds even without the query engine; check the cache binary.
# prisma generate is code-gen only — no secret resolution (r-coo92 VIII)
_LITELLM_CELLAR="$(brew --cellar litellm 2>/dev/null)/$(brew list --versions litellm 2>/dev/null | awk '{print $2}')"
_VENV="$_LITELLM_CELLAR/libexec/venv"
_PRISMA="$_VENV/bin/prisma"
_SCHEMA="$_VENV/lib/python3.12/site-packages/litellm/proxy/schema.prisma"
if [[ -x "$_PRISMA" && -f "$_SCHEMA" ]]; then
	_QE=$(find "$HOME/.cache/prisma-python" -name "query-engine-darwin-arm64" 2>/dev/null | head -1)
	if [[ -z "$_QE" || ! -x "$_QE" ]]; then
		echo "prisma query engine missing — regenerating" >&2
		PATH="$_VENV/bin:$PATH" "$_PRISMA" generate --schema="$_SCHEMA" >/dev/null 2>&1 || true
	fi
	unset _QE
fi
unset _LITELLM_CELLAR _VENV _PRISMA _SCHEMA

exec litellm --config "$LITELLM_CFG" --port "$LITELLM_PORT" --host 127.0.0.1 >>"$LOG" 2>&1
