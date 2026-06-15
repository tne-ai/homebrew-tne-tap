class Cooldowns < Formula
  desc "Set and check dependency cooldown configurations across package managers"
  homepage "https://cooldowns.dev"
  # Pinned to a reviewed upstream commit. Bumps land via PR with diff review.
  # See r-ciso95-third-party-tool-tap (in tne-ai/tne-plugins) for the bump
  # discipline.
  #
  # Upstream:    https://github.com/mprpic/cooldowns
  # Pinned SHA:  45f389432e3a9c568ed0a6190d82fb34028eb97f  (HEAD as of 2026-06-14)
  # Audited by:  richtong @ 2026-06-14
  # Threat-surface notes:
  #   - Pure bash, no network calls, no eval of remote content
  #   - Writes to /etc/profile.d/ or ~/.zshrc, ~/.bashrc, ~/.npmrc, ~/.bunfig.toml
  #     (all user-owned; no root escalation)
  #   - Supports: pip, uv, poetry, npm, pnpm, yarn, bun, deno, cargo, bundler
  #   - Does NOT modify brew itself -- pair with brew-cooldown-check (see
  #     r-ciso94-supply-chain-cooldown).
  url "https://github.com/mprpic/cooldowns/archive/45f389432e3a9c568ed0a6190d82fb34028eb97f.tar.gz"
  version "0+45f3894"
  sha256 "f3a1085a4d4b1319b84b0974a2a5b1a7881df430255130b2539baefb34ab358d"
  license "MIT"

  def install
    bin.install "cooldowns.sh"
  end

  test do
    output = shell_output("#{bin}/cooldowns.sh 2>&1", 1)
    assert_match "set", output
    assert_match "check", output
  end
end
