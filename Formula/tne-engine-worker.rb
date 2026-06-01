class TneEngineWorker < Formula
  desc "TNE Temporal workflow worker — executes tne-engine skill activities"
  homepage "https://github.com/tne-ai/tne-plugins"
  # No versioned archive — worker ships as part of the tne-plugins marketplace cache.
  # Formula manages the service lifecycle only; the engine code lives at:
  #   ~/.claude/plugins/marketplaces/tne-plugins/plugins/tne/engine/
  version "0.1.0"
  license "MIT"

  depends_on "uv"

  # No install step — engine code is managed by the plugin marketplace, not Homebrew.
  # This formula exists solely to register the service with brew services.
  def install
    engine_dir = File.expand_path("~/.claude/plugins/marketplaces/tne-plugins/plugins/tne/engine")
    (bin/"tne-engine-worker").write <<~EOS
      #!/bin/bash
      ENGINE_DIR="${TNE_ENGINE_DIR:-#{engine_dir}}"
      if [[ ! -f "$ENGINE_DIR/pyproject.toml" ]]; then
        echo "tne-engine not found at $ENGINE_DIR" >&2
        echo "Run: /marketplace → tne-plugins → Install" >&2
        exit 1
      fi
      export TNE_ENGINE_ALLOWED=1
      # Run from engine parent dir so relative imports in engine package resolve.
      cd "$(dirname "$ENGINE_DIR")" || exit 1
      exec uv run --project engine python -m engine.temporal_worker "$@"
    EOS
    chmod 0755, bin/"tne-engine-worker"
  end

  service do
    run [opt_bin/"tne-engine-worker"]
    keep_alive true
    log_path var/"log/tne-engine-worker.log"
    error_log_path var/"log/tne-engine-worker.log"
    environment_variables TNE_ENGINE_ALLOWED: "1"
    working_dir Dir.home
  end

  test do
    assert_predicate bin/"tne-engine-worker", :executable?
  end
end
