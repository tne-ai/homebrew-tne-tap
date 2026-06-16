class TemporalDev < Formula
  desc "Temporal CLI with persistent-DB dev server (TNE variant of homebrew-core temporal)"
  homepage "https://temporal.io/"
  url "https://github.com/temporalio/cli/archive/refs/tags/v1.7.1.tar.gz"
  sha256 "a1debb5f6ff517a95ee131538afa605951ba0034c2b3d512ff0239082f1864fa"
  license "MIT"
  head "https://github.com/temporalio/cli.git", branch: "main"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end


  depends_on "go" => :build

  def install
    v = build.head? ? "0.0.0-HEAD+#{Utils.git_short_head}" : version.to_s
    ldflags = "-s -w -X github.com/temporalio/cli/internal/temporalcli.Version=#{v}"
    system "go", "build", *std_go_args(ldflags:, output: bin/"temporal"), "./cmd/temporal"

    (var/"temporal").mkpath
    generate_completions_from_executable(bin/"temporal", shell_parameter_format: :cobra)
  end

  service do
    run [opt_bin/"temporal", "server", "start-dev",
         "--db-filename", var/"temporal/temporal.db",
         "--ui-port", "8233"]
    keep_alive :crashed
    error_log_path var/"log/temporal.log"
    log_path var/"log/temporal.log"
    working_dir var/"temporal"
  end

  test do
    run_output = shell_output("#{bin}/temporal --version")
    assert_match "temporal version #{version}", run_output

    run_output = shell_output("#{bin}/temporal workflow list --address 192.0.2.0:1234 2>&1", 1)
    assert_match "failed reaching server", run_output
  end
end
