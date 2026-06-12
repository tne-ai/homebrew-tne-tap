class Tinyclaw < Formula
  desc "Messaging bridge connecting WhatsApp/Telegram/Discord to Claude Code CLI"
  homepage "https://github.com/TinyAGI/tinyclaw"
  url "https://github.com/TinyAGI/tinyclaw/archive/refs/tags/v0.0.20.tar.gz"
  sha256 "23f783e035d73fc528b1ce8ca67727751d82c96b83c04fa4e1f7968345dcf185"
  version "0.0.20"
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
