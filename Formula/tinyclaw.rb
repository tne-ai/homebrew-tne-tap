class Tinyclaw < Formula
  desc "Messaging bridge connecting WhatsApp/Telegram/Discord to Claude Code CLI"
  homepage "https://github.com/TinyAGI/tinyclaw"
  url "https://github.com/TinyAGI/tinyclaw/archive/refs/tags/v0.0.9.tar.gz"
  sha256 "759b32c393062e0da579e5d73e6d4c90c2e6fa059e285c0043a4c4d7b4abbe3b"
  version "0.0.9"
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
