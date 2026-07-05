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

  # NOT a brew service. litellm requires interactive 1Password secrets, which a
  # launchd agent cannot resolve at login (the desktop app is not yet unlocked).
  # This is r-cto-ops92 Pattern C: secret-requiring services run foreground from a
  # post-login shell whose .envrc has resolved op:// via `op inject` (r-cto-dev154).
  # Launcher: tne-ai/bin/start-ai.sh → litellm-start.sh. Only mlflow (no secrets)
  # is a brew service (Pattern B).

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
    # No service scripts installed — litellm is launched foreground by
    # tne-ai/bin/start-ai.sh → litellm-start.sh (Pattern C), not by launchd.
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
      litellm is installed. It is NOT a brew service by design — it needs
      interactive 1Password secrets that a launchd agent cannot resolve at
      login (r-cto-ops92 Pattern C).

      Start it from a shell where direnv has resolved secrets via op inject:

        install-litellm.sh          # seed ~/.config/litellm/config.yaml (first run)
        bash start-ai.sh            # tne-ai/bin — sources .envrc, execs litellm-start.sh

      Config:  ~/.config/litellm/config.yaml
      Logs:    ~/ws/logs/litellm.log
    EOS
  end

  test do
    assert_match "litellm", shell_output("#{bin}/litellm --version 2>&1")
  end
end
