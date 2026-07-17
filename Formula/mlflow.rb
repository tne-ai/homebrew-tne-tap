class Mlflow < Formula
  desc "MLflow — open-source platform for ML lifecycle: tracking, models, registry"
  homepage "https://github.com/mlflow/mlflow"
  url "https://files.pythonhosted.org/packages/8e/69/d71afc475fa7e7b22bb27392247d2a3015c9da202dea44f150a54be4bd67/mlflow-3.13.0.tar.gz"
  sha256 "a95198d592a8a15fad3db7f56b228acc9422c09f0daa7c6c976a9996ab73c3e2"
  version "3.13.0"
  license "Apache-2.0"

  depends_on "uv"
  depends_on "python@3.12"

  # Config seeding: brew install does NOT write to /opt/homebrew/etc/.
  # Runtime state belongs in $TNE_DB_DIR/mlflow/ and $TNE_LOG_DIR/.
  # install-ai.sh sets MLFLOW_TRACKING_URI; start-ai.sh creates the directories.

  def install
    venv = libexec/"venv"
    system "uv", "venv", venv, "--python", "python3.12"
    # uv venv does not seed pip; use uv's own installer against the venv interpreter
    # (matches the litellm formula). venv/bin/pip does not exist.
    system "uv", "pip", "install", "--python", venv/"bin/python", "mlflow==#{version}"

    %w[mlflow mlflow-skinny].each do |cmd|
      next unless (venv/"bin"/cmd).exist?
      (bin/cmd).write <<~SH
        #!/bin/bash
        exec "#{venv}/bin/#{cmd}" "$@"
      SH
    end

    # Serve wrapper embedded inline — buildpath holds only the PyPI tarball (r-cto-ops92 IX)
    (bin/"mlflow-serve").write <<~'SH'
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
    SH
    chmod 0755, bin/"mlflow-serve"
  end

  # Pattern A (r-cto-ops92): no secrets needed — MLflow uses only local paths.
  # mlflow-serve is bin.install'd so service do references only the brew prefix.
  service do
    run [opt_bin/"mlflow-serve"]
    keep_alive({ successful_exit: false })
    log_path "#{Dir.home}/ws/logs/mlflow.log"
    error_log_path "#{Dir.home}/ws/logs/mlflow.log"
    environment_variables PATH: "#{HOMEBREW_PREFIX}/bin:#{Dir.home}/.local/bin:/usr/local/bin:/usr/bin:/bin",
                          HOME: Dir.home,
                          MLFLOW_PORT: "5001",
                          MLFLOW_DIR: "#{Dir.home}/ws/db/mlflow"
    working_dir Dir.home
  end

  def caveats
    <<~EOS
      Start mlflow:
        brew services start tne-ai/tne-tap/mlflow

      Tracking URI:  http://localhost:${MLFLOW_PORT:-5001}
      DB:            ${MLFLOW_DIR:-~/ws/db/mlflow}/mlflow.db
      Artifacts:     ${MLFLOW_DIR:-~/ws/db/mlflow}/artifacts/
      Logs:          ~/ws/logs/mlflow.log

      Override defaults (restart required):
        MLFLOW_PORT — tracking server port (default: 5001)
        MLFLOW_DIR  — DB + artifact root (default: ~/ws/db/mlflow)
    EOS
  end

  test do
    assert_match "mlflow", shell_output("#{bin}/mlflow --version 2>&1")
  end
end
