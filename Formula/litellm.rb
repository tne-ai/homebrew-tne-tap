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

    # litellm[proxy] omits several runtime deps from its own requirements.
    # - prisma<7: Prisma 7 dropped schema.prisma url= syntax that litellm 1.x uses.
    # - mlflow: success_callback integration needs mlflow in the same venv.
    system venv/"bin/python3", "-m", "ensurepip"
    system venv/"bin/python3", "-m", "pip", "install", "prisma>=0.11.0,<7", "mlflow>=2.0,<4"
    schema = venv/"lib/python3.12/site-packages/litellm/proxy/schema.prisma"
    with_env(PATH: "#{venv}/bin:#{ENV["PATH"]}") do
      system venv/"bin/prisma", "generate", "--schema=#{schema}"
    end

    (bin/"litellm").write <<~SH
      #!/bin/bash
      exec "#{venv}/bin/litellm" "$@"
    SH
  end


  def caveats
    <<~EOS
      litellm is installed. It is NOT configured as a brew service by design.

      LiteLLM requires API-key secrets (LITELLM_MASTER_KEY, provider keys).
      Pattern C (r-cto-ops92): the daemon runs foreground from a shell that
      already has secrets resolved by .envrc — never via a launchd plist that
      would store plaintext on disk.

      To start the proxy (TNE workflow):
        install-litellm.sh       # from tne-ai/bin — generates ~/.config/litellm/config.yaml
        make ai                  # or: bash start-ai.sh — sources .envrc, execs litellm-start.sh

      Config:  ~/.config/litellm/config.yaml
      Logs:    $TNE_LOG_DIR/litellm.log  (default: ~/ws/logs/litellm.log)

      External users who don't share TNE's no-plaintext-on-disk policy can
      author their own ~/Library/LaunchAgents/*.plist with literal
      EnvironmentVariables and `launchctl bootstrap` it directly. The formula
      intentionally does not ship that plist.
    EOS
  end

  test do
    assert_match "litellm", shell_output("#{bin}/litellm --version 2>&1")
  end
end
