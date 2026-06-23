#!/usr/bin/env bash
# mlflow-serve.sh — start MLflow tracking server in the foreground (for brew services).
# brew services manages the process lifecycle; this script must not background itself.
# r-coo92: no 1Password secrets needed — MLflow uses only local paths.
set -euo pipefail
SCRIPT_DIR=${SCRIPT_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
MLFLOW_PORT="${MLFLOW_PORT:-5001}"
WS_DIR="${WS_DIR:-$HOME/ws}"
TNE_LOG_DIR="${TNE_LOG_DIR:-$WS_DIR/logs}"
MLFLOW_DIR="${MLFLOW_DIR:-$WS_DIR/db/mlflow}"
LOG="${TNE_LOG_DIR}/mlflow.log"
mkdir -p "${MLFLOW_DIR}/artifacts" "${TNE_LOG_DIR}"
exec mlflow server \
	--host 127.0.0.1 \
	--port "${MLFLOW_PORT}" \
	--backend-store-uri "sqlite:///${MLFLOW_DIR}/mlflow.db" \
	--default-artifact-root "${MLFLOW_DIR}/artifacts" \
	>>"${LOG}" 2>&1
