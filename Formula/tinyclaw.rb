class Tinyclaw < Formula
  desc "Messaging bridge connecting WhatsApp/Telegram/Discord to Claude Code CLI"
  homepage "https://github.com/TinyAGI/tinyclaw"
  url "https://github.com/TinyAGI/tinyclaw/archive/refs/heads/main.tar.gz"
  sha256 "73358b538344745ab7bd9bddd7b9a1e4115a68ff45f189b5bfe8380fbc9a1087"
  version "0.1.0"
  license "MIT"

  depends_on "node"

  def install
    system "npm", "install", *std_npm_args(prefix: false)
    system "npm", "run", "build" if File.exist?("tsconfig.json")
    libexec.install Dir["*"]
    (bin/"tinyclaw").write_env_script libexec/"bin/tinyclaw", PATH: "#{Formula["node"].opt_bin}:$PATH"
  end

  test do
    assert_match "tinyclaw", shell_output("#{bin}/tinyclaw --help 2>&1", 1)
  end
end
