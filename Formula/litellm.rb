class Litellm < Formula
  desc "LiteLLM proxy — unified OpenAI-compatible API gateway for 100+ LLM providers"
  homepage "https://github.com/BerriAI/litellm"
  # renovate: datasource=pypi depName=litellm
  url "https://files.pythonhosted.org/packages/e8/1b/de398e6cef46d4cbc4395c895330f30eab05439bf6d0c5c53b0203661eeb/litellm-1.89.1.tar.gz"
  sha256 "eb9292f90afe46dcce4bfef6bbeaa54494945813763e1c0917f4e9a1c584c1a4"
  version "1.89.1"
  license "MIT"

  depends_on "uv"
  depends_on "python@3.12"

  # Config seeding: brew install does NOT write to /opt/homebrew/etc/.
  # Runtime config belongs in ~/.config/litellm/ (XDG).
  # install-litellm.sh seeds ~/.config/litellm/config.yaml on first run.

  # Pattern B (r-cto-ops92): op-launcher resolves 1Password secrets at launchd boot.
  # All scripts are bin.install'd — no paths outside the brew prefix (r-cto-ops92 IX).
  # Break-glass: populate ~/.config/litellm/secrets.env (gitignored) if 1Password unavailable.
  service do
    run [opt_bin/"op-launcher",
         "--env-file", "#{Dir.home}/.config/litellm/secrets.env.tpl",
         "--", opt_bin/"litellm-start"]
    keep_alive({ successful_exit: false })
    environment_variables(
      PATH:                  "#{HOMEBREW_PREFIX}/bin:#{Dir.home}/.local/bin:/usr/local/bin:/usr/bin:/bin",
      HOME:                  Dir.home,
      ANTHROPIC_API_KEY:     "op://DevOps/Anthropic API Key Dev/api key",
      MINIMAX_API_KEY:       "op://DevOps/MiniMax API Key Dev/api key",
      MINIMAX_PLAN_KEY:      "op://DevOps/MiniMax API Key Dev/coding plan key",
      Z_AI_PLAN_KEY:         "op://DevOps/Z.ai Plan Key Dev/api key",
      MOONSHOT_API_KEY:      "op://DevOps/fs4np24dsdyz5smfrxxwxrodri/api key",
      DEEPSEEK_API_KEY:      "op://DevOps/deepseek API Key Dev/api key",
      OPENROUTER_API_KEY:    "op://DevOps/OpenRouter API Key Dev/key",
      LITELLM_MASTER_KEY:    "op://DevOps/LiteLLM Auth Token Dev/auth token",
      SAMBANOVA_API_KEY:     "op://DevOps/Sambanova API Token Dev/api token",
      LM_STUDIO_API_TOKEN:   "op://Private/LM Studio API Token Dev/api token",
      CLIPROXYAPI_KEY:       "op://DevOps/CLIProxyAPI Key Dev/api key",
      OP_LAUNCH_FALLBACK_ENV:"#{Dir.home}/.config/litellm/secrets.env",
    )
    log_path       "#{Dir.home}/ws/logs/litellm.log"
    error_log_path "#{Dir.home}/ws/logs/litellm.log"
  end

  def install
    # Install into an isolated venv in libexec so it doesn't pollute the system Python.
    venv = libexec/"venv"
    system "uv", "venv", venv, "--python", "python3.12"
    system "uv", "pip", "install", "--python", venv/"bin/python", "litellm[proxy]==#{version}"

    # litellm[proxy] omits several runtime deps from its own requirements.
    # - prisma: Python prisma client (pypi package, currently 0.x — unrelated to Node.js prisma).
    #   The old <7 upper bound was incorrect (confused Node prisma 7 with Python prisma).
    #   Python prisma package will not reach version 7; upper bound removed.
    # - mlflow: success_callback integration needs mlflow in the same venv.
    system venv/"bin/python3", "-m", "ensurepip"
    # renovate: datasource=pypi depName=prisma
    # renovate: datasource=pypi depName=mlflow
    system venv/"bin/python3", "-m", "pip", "install", "prisma>=0.11.0", "mlflow>=2.0,<4"
    schema = venv/"lib/python3.12/site-packages/litellm/proxy/schema.prisma"
    with_env(PATH: "#{venv}/bin:#{ENV["PATH"]}") do
      system venv/"bin/prisma", "generate", "--schema=#{schema}"
    end

    (bin/"litellm").write <<~SH
      #!/bin/bash
      exec "#{venv}/bin/litellm" "$@"
    SH

    # Service scripts embedded inline — buildpath holds only the PyPI tarball,
    # so tap files must be written here (r-cto-ops92 IX: brew-prefix paths only).
    (bin/"op-launcher").write <<~'SH'
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
    SH
    chmod 0755, bin/"op-launcher"
    (bin/"litellm-start").write <<~'SH'
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
    SH
    chmod 0755, bin/"litellm-start"
  end


  def post_install
    venv = libexec/"venv"
    schema = venv/"lib/python3.12/site-packages/litellm/proxy/schema.prisma"
    return unless schema.exist?

    with_env(PATH: "#{venv}/bin:#{ENV["PATH"]}") do
      system venv/"bin/prisma", "generate", "--schema=#{schema}"
    end
  end

  def caveats
    <<~EOS
      litellm is installed. Start it as a managed service:

        brew services start tne-ai/tne-tap/litellm

      Requires the 1Password desktop app running — secrets are injected via
      op run at launchd boot (r-cto-ops92 Pattern B, r-cto-dev155).

      Break-glass (no 1Password): populate ~/.config/litellm/secrets.env
      with plain KEY=value pairs (gitignored, never committed).

      Config:  ~/.config/litellm/config.yaml
      Logs:    ~/ws/logs/litellm.log
    EOS
  end

  test do
    assert_match "litellm", shell_output("#{bin}/litellm --version 2>&1")
  end
end
