class TneEngineWorker < Formula
  desc "TNE Temporal workflow worker — executes tne-engine skill activities"
  homepage "https://github.com/tne-ai/tne-plugins"
  # Private repo — HEAD-only formula. Install with:
  #   brew install --HEAD tne-ai/tne-tap/tne-engine-worker
  # To upgrade to latest engine code:
  #   brew upgrade --fetch-HEAD tne-engine-worker && brew services restart tne-engine-worker
  # To point the worker at a live checkout instead of libexec (e.g. via install-ai.sh):
  #   set TNE_ENGINE_DIR in the launchd override plist — see install-ai.sh
  head do
    url "https://github.com/tne-ai/tne-plugins.git", branch: "main"
  end
  version "0.1.20260805"
  license "MIT"

  depends_on "uv"

  def install
    # Install engine package from the cloned source into libexec.
    # This makes the worker self-contained — no dependency on the plugin marketplace.
    (libexec/"engine").mkpath
    (libexec/"engine").install Dir["plugins/tne/engine/*"]

    # Pre-build the venv in libexec so workers start instantly without re-syncing.
    system "uv", "sync", "--project", libexec/"engine"

    # ENGINE_DIR resolution order:
    #   1. TNE_ENGINE_DIR env var (explicit override — for dev/testing against a local checkout)
    #   2. libexec/engine (default — the self-contained cellar copy installed above)
    (bin/"tne-engine-worker").write <<~EOS
      #!/bin/bash
      ENGINE_DIR="${TNE_ENGINE_DIR:-#{libexec}/engine}"
      if [[ ! -f "$ENGINE_DIR/pyproject.toml" ]]; then
        echo "tne-engine not found at $ENGINE_DIR" >&2
        exit 1
      fi
      export TNE_ENGINE_ALLOWED=1
      cd "$(dirname "$ENGINE_DIR")" || exit 1
      exec uv run --project engine python -m engine.temporal_worker "$@"
    EOS
    chmod 0755, bin/"tne-engine-worker"

    (bin/"tne-engine").write <<~EOS
      #!/bin/bash
      ENGINE_DIR="${TNE_ENGINE_DIR:-#{libexec}/engine}"
      if [[ ! -f "$ENGINE_DIR/pyproject.toml" ]]; then
        echo "tne-engine not found at $ENGINE_DIR" >&2
        exit 1
      fi
      export TNE_ENGINE_ALLOWED=1
      cd "$(dirname "$ENGINE_DIR")" || exit 1
      exec uv run --project engine python -m engine "$@"
    EOS
    chmod 0755, bin/"tne-engine"
  end

  service do
    run [opt_bin/"tne-engine-worker"]
    keep_alive true
    log_path var/"log/tne-engine-worker.log"
    error_log_path var/"log/tne-engine-worker.log"
    environment_variables TNE_ENGINE_ALLOWED: "1",
                          UV_KEYRING_PROVIDER: "disabled",
                          PATH: "#{HOMEBREW_PREFIX}/bin:#{HOMEBREW_PREFIX}/sbin:/usr/local/bin:/usr/bin:/bin"
    working_dir Dir.home
  end

  # ThrottleInterval=10: minimum seconds between restarts — prevents tight crash loops.
  # brew's service do DSL has no direct key for this so we patch the generated plist.
  def plist
    super.merge("ThrottleInterval" => 10)
  end

  test do
    assert_predicate bin/"tne-engine-worker", :executable?
    assert_predicate bin/"tne-engine", :executable?
    # Verify the engine package is installed in libexec, not a marketplace path
    assert_predicate libexec/"engine/pyproject.toml", :exist?
  end
end
