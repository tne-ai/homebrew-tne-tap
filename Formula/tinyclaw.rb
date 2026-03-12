class Tinyclaw < Formula
  desc "Messaging bridge connecting WhatsApp/Telegram/Discord to Claude Code CLI"
  homepage "https://github.com/TinyAGI/tinyclaw"
  url "https://github.com/TinyAGI/tinyclaw/archive/refs/tags/v0.0.10.tar.gz"
  sha256 "7a92fcaabd839b80a8eb4a8c1c68ee75baf2cb8add6154c99033fc654fd535ce"
  version "0.0.10"
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
