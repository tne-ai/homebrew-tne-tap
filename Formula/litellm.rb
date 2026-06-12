class Litellm < Formula
  desc "LiteLLM proxy — unified OpenAI-compatible API gateway for 100+ LLM providers"
  homepage "https://github.com/BerriAI/litellm"
  url "https://files.pythonhosted.org/packages/16/ea/f99ececb7f22703fe120f1d8be9ffb749ec9453fbbbbbebc0d6a6b4d7864/litellm-1.88.1.tar.gz"
  sha256 "89c6b74cc7912d6365793006ff951c0450fe847625008dfe49de8a7dc4529aa5"
  version "1.88.1"
  license "MIT"

  depends_on "uv"
  depends_on "python@3.12"

  # Config seeding: brew install does NOT write to /opt/homebrew/etc/.
  # Runtime config belongs in ~/.config/litellm/ (XDG).
  # install-litellm.sh seeds ~/.config/litellm/config.yaml on first run.

  def install
    # Install into an isolated venv in libexec so it doesn't pollute the system Python.
    venv = libexec/"venv"
    system "uv", "venv", venv, "--python", "python3.12"
    system "uv", "pip", "install", "--python", venv/"bin/python", "litellm[proxy]==#{version}"

    (bin/"litellm").write <<~SH
      #!/bin/bash
      exec "#{venv}/bin/litellm" "$@"
    SH
  end


  service do
    # litellm-start.sh injects 1Password secrets at runtime (r-coo92).
    # DATABASE_URL, MLFLOW_TRACKING_URI, and provider API keys are set there.
    run ["#{Dir.home}/ws/git/src/bin/litellm-start.sh"]
    keep_alive true
    log_path "#{Dir.home}/ws/logs/litellm.log"
    error_log_path "#{Dir.home}/ws/logs/litellm.log"
    environment_variables PATH: "#{HOMEBREW_PREFIX}/bin:#{Dir.home}/.local/bin:/usr/local/bin:/usr/bin:/bin",
                          HOME: Dir.home
    working_dir Dir.home
  end
  def caveats
    <<~EOS
      litellm is installed but not configured.

      Seed your config and start the proxy:
        install-litellm.sh       # from tne-ai/bin — generates config + LaunchAgent
        make litellm             # or: bash start-ai.sh

      Config lives at: ~/.config/litellm/config.yaml
      Secrets injected at runtime via: litellm-start.sh (op inject)
      Logs at: $TNE_LOG_DIR/litellm.log  (default: ~/ws/logs/litellm.log)
    EOS
  end

  test do
    assert_match "litellm", shell_output("#{bin}/litellm --version 2>&1")
  end
end
