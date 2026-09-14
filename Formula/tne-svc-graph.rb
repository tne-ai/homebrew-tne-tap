class TneSvcGraph < Formula
  desc "TNE graph-svc — durable multi-tenant graph database microservice (LadybugDB/Fastify)"
  homepage "https://github.com/tne-ai/svc-graph"
  # Private repo — HEAD-only formula. Install with:
  #   brew install --HEAD tne-ai/tne-tap/tne-svc-graph
  # To upgrade to latest svc-graph code:
  #   brew upgrade --fetch-HEAD tne-svc-graph && brew services restart tne-svc-graph
  # To point the service at a live checkout instead of libexec (e.g. via install-ai.sh):
  #   set TNE_SVC_GRAPH_DIR in the launchd override plist — see install-ai.sh
  head do
    url "https://github.com/tne-ai/svc-graph.git", branch: "main"
  end
  version "0.1.20260906"
  license "MIT"

  depends_on "node"

  def install
    # Install svc-graph source into libexec and build it there — self-contained,
    # no dependency on a sys/svc-graph sibling monorepo checkout
    # (r-cai-arch-plugin-standalone-storage).
    (libexec/"svc-graph").mkpath
    (libexec/"svc-graph").install Dir["*"]

    cd libexec/"svc-graph" do
      system "npm", "install"
      system "npm", "run", "build"
    end

    # SVC_GRAPH_DIR resolution order:
    #   1. TNE_SVC_GRAPH_DIR env var (explicit override — dev/testing against a local checkout)
    #   2. libexec/svc-graph (default — the self-contained cellar copy installed above)
    (bin/"tne-svc-graph").write <<~EOS
      #!/bin/bash
      SVC_GRAPH_DIR="${TNE_SVC_GRAPH_DIR:-#{libexec}/svc-graph}"
      if [[ ! -f "$SVC_GRAPH_DIR/dist/index.js" ]]; then
        echo "svc-graph build not found at $SVC_GRAPH_DIR" >&2
        exit 1
      fi
      cd "$SVC_GRAPH_DIR" || exit 1
      exec node dist/index.js "$@"
    EOS
    chmod 0755, bin/"tne-svc-graph"
  end

  service do
    run [opt_bin/"tne-svc-graph"]
    keep_alive true
    log_path var/"log/tne-svc-graph.log"
    error_log_path var/"log/tne-svc-graph.log"
    environment_variables PORT: "8002",
                          GRAPH_DATA_DIR: "#{var}/tne-svc-graph/data",
                          PATH: "#{HOMEBREW_PREFIX}/bin:#{HOMEBREW_PREFIX}/sbin:/usr/local/bin:/usr/bin:/bin"
    working_dir Dir.home
  end

  # ThrottleInterval=10: minimum seconds between restarts — prevents tight crash loops.
  # brew's service do DSL has no direct key for this so we patch the generated plist.
  def plist
    super.merge("ThrottleInterval" => 10)
  end

  test do
    assert_predicate bin/"tne-svc-graph", :executable?
    # Verify the build landed in libexec, not a marketplace/monorepo path
    assert_predicate libexec/"svc-graph/dist/index.js", :exist?
  end
end
