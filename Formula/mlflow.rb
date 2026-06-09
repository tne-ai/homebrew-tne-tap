class Mlflow < Formula
  desc "MLflow — open-source platform for ML lifecycle: tracking, models, registry"
  homepage "https://github.com/mlflow/mlflow"
  url "https://files.pythonhosted.org/packages/8e/69/d71afc475fa7e7b22bb27392247d2a3015c9da202dea44f150a54be4bd67/mlflow-3.13.0.tar.gz"
  sha256 "a95198d592a8a15fad3db7f56b228acc9422c09f0daa7c6c976a9996ab73c3e2"
  version "3.13.0"
  license "Apache-2.0"

  depends_on "uv"
  depends_on "python@3.12"

  # Config seeding: brew install does NOT write to /opt/homebrew/etc/.
  # Runtime state belongs in $TNE_DB_DIR/mlflow/ and $TNE_LOG_DIR/.
  # install-ai.sh sets MLFLOW_TRACKING_URI; start-ai.sh creates the directories.

  def install
    venv = libexec/"venv"
    system "uv", "venv", venv, "--python", "python3.12"
    system venv/"bin/pip", "install", "mlflow==#{version}"

    %w[mlflow mlflow-skinny].each do |cmd|
      next unless (venv/"bin"/cmd).exist?
      (bin/cmd).write <<~SH
        #!/bin/bash
        exec "#{venv}/bin/#{cmd}" "$@"
      SH
    end
  end

  def caveats
    <<~EOS
      mlflow is installed but not started.

      Start via the AI stack:
        bash start-ai.sh         # from tne-ai/bin — starts mlflow + full stack
        make mlflow              # or standalone

      Tracking URI:  http://localhost:5001
      DB:            $TNE_DB_DIR/mlflow/mlflow.db  (default: ~/ws/db/mlflow/)
      Artifacts:     $TNE_DB_DIR/mlflow/artifacts/
      Logs:          $TNE_LOG_DIR/mlflow.log
    EOS
  end

  test do
    assert_match "mlflow", shell_output("#{bin}/mlflow --version 2>&1")
  end
end
