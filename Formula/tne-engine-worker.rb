class TneEngineWorker < Formula
  desc "TNE Temporal workflow worker — executes tne-engine skill activities"
  homepage "https://github.com/tne-ai/tne-plugins"
  # Private repo — HEAD-only formula. Install with:
  #   brew install --HEAD tne-ai/tne-tap/tne-engine-worker
  # The install block writes a wrapper script inline; no archive content is used.
  # version/url are bumped by .github/workflows/bump-formula.yml for audit trail.
  head do
    url "git@github.com:tne-ai/tne-plugins.git", branch: "main"
  end
  version "0.1.20260601"
  license "MIT"

  depends_on "uv"

  # Engine code is managed by the plugin marketplace, not Homebrew.
  # This formula installs a wrapper script and registers the brew service.
  def install
    (bin/"tne-engine-worker").write <<~EOS
      #!/bin/bash
      ENGINE_DIR="${TNE_ENGINE_DIR:-$HOME/.claude/plugins/marketplaces/tne-plugins/plugins/tne/engine}"
      if [[ ! -f "$ENGINE_DIR/pyproject.toml" ]]; then
        echo "tne-engine not found at $ENGINE_DIR" >&2
        echo "Run: /marketplace -> tne-plugins -> Install" >&2
        exit 1
      fi
      export TNE_ENGINE_ALLOWED=1
      # cd to engine parent so 'engine' package resolves as a top-level import.
      cd "$(dirname "$ENGINE_DIR")" || exit 1
      exec uv run --project engine python -m engine.temporal_worker "$@"
    EOS
    chmod 0755, bin/"tne-engine-worker"

    # tne-engine: CLI client — submits workflows / runs skills from the command line.
    # Same ENGINE_DIR resolution as the worker; runs python -m engine (not the worker).
    (bin/"tne-engine").write <<~EOS
      #!/bin/bash
      ENGINE_DIR="${TNE_ENGINE_DIR:-$HOME/.claude/plugins/marketplaces/tne-plugins/plugins/tne/engine}"
      if [[ ! -f "$ENGINE_DIR/pyproject.toml" ]]; then
        echo "tne-engine not found at $ENGINE_DIR" >&2
        echo "Run: /marketplace -> tne-plugins -> Install" >&2
        exit 1
      fi
      export TNE_ENGINE_ALLOWED=1
      # cd to engine parent so 'engine' package resolves as a top-level import.
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
                          PATH: "#{HOMEBREW_PREFIX}/bin:#{HOMEBREW_PREFIX}/sbin:/usr/local/bin:/usr/bin:/bin"
    working_dir Dir.home
  end

  test do
    assert_predicate bin/"tne-engine-worker", :executable?
    assert_predicate bin/"tne-engine", :executable?
  end
end
