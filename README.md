# TNE Homebrew Tap

Homebrew formulae for TNE tools.

## Usage

```bash
brew tap tne-ai/tne-tap
brew install cooldowns
```

## Available Formulae

| Formula | Description |
|---------|-------------|
| `tinyclaw` | Messaging bridge connecting WhatsApp/Telegram/Discord to Claude Code CLI |
| `cooldowns` | Set and check dependency cooldown configurations across package managers (pip, uv, poetry, npm, pnpm, yarn, bun, deno, cargo, bundler). Repackages [mprpic/cooldowns](https://github.com/mprpic/cooldowns) at a pinned SHA. |

## Why this tap exists

We re-publish third-party CLIs through this pinned tap instead of vendoring
or `curl | sh`. Every version bump lands as a reviewed PR with the
upstream diff visible. Governed by
[`r-ciso95-third-party-tool-tap`](https://github.com/tne-ai/tne-plugins/blob/main/plugins/tne/skills/r-ciso95-third-party-tool-tap/SKILL.md)
in the tne-plugins ethos.

## Bumping a formula

1. Compare your local formula's pinned SHA against upstream HEAD
2. Read the diff: `gh repo view <upstream> -w` or `git diff <old>..<new>`
3. If the diff is clean, update `url`, `version`, and `sha256` in the formula
4. Open a PR with the diff summary in the body
5. The `w-cto-sec-tap-upstream-bump` watchdog (in tne-plugins) does the first
   three steps automatically once a week

## Local install

```bash
git clone git@github.com:tne-ai/homebrew-tne-tap.git
brew install --formula ./Formula/cooldowns.rb
```
