class Litellm < Formula
  desc "LiteLLM proxy — unified OpenAI-compatible API gateway for 100+ LLM providers"
  homepage "https://github.com/BerriAI/litellm"
  # renovate: datasource=pypi depName=litellm
  url "https://files.pythonhosted.org/packages/56/f1/f7cfead063f2ab1877c8fb465d0d7fe300b75f081bcb73525f6d550aeb1c/litellm-1.89.3.tar.gz"
  sha256 "8fcdb2b7a0ef3381d41adf164443842e31ef9f0cd5bcda6fc3c0bd8bc2959510"
  version "1.89.3"
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

    # Install service scripts so service do references only the brew prefix (r-cto-ops92 IX)
    bin.install buildpath/"op-launcher.sh" => "op-launcher"
    bin.install buildpath/"litellm-start.sh" => "litellm-start"
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
