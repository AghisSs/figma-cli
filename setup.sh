#!/usr/bin/env bash
# One-command setup for figma-cli on macOS / Linux.
#
#   curl -fsSL https://raw.githubusercontent.com/AghisSs/figma-cli/main/setup.sh | bash
#
# What it does:
#   1. checks for git and Node >= 18 (tells you how to install them if missing)
#   2. clones (or updates) https://github.com/AghisSs/figma-cli into ~/figma-cli
#   3. runs npm install there
#   4. if Claude Code is installed, opens it in that folder with the connect prompt
#
# It never touches Figma itself. Connecting happens when you (or Claude) run
# `figma-cli connect` inside ~/figma-cli.
set -euo pipefail

REPO_URL="${FIGMA_CLI_REPO:-https://github.com/AghisSs/figma-cli}"
TARGET="${FIGMA_CLI_DIR:-$HOME/figma-cli}"
BRANCH="${FIGMA_CLI_BRANCH:-main}"

say()  { printf '\033[1;36m›\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

# 1. prerequisites -----------------------------------------------------------
command -v git >/dev/null 2>&1 || fail "git is not installed. On macOS run: xcode-select --install"

if ! command -v node >/dev/null 2>&1; then
  fail "Node.js is not installed. Install it from https://nodejs.org (LTS) or with: brew install node"
fi
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$NODE_MAJOR" -lt 18 ]; then
  fail "Node.js $(node -v) is too old; figma-cli needs 18 or newer. Upgrade at https://nodejs.org"
fi
ok "git and Node $(node -v) found"

# 2. clone or update ---------------------------------------------------------
if [ -d "$TARGET/.git" ]; then
  say "Updating existing checkout in $TARGET"
  git -C "$TARGET" fetch --quiet origin "$BRANCH"
  git -C "$TARGET" checkout --quiet "$BRANCH"
  git -C "$TARGET" pull --quiet --ff-only origin "$BRANCH"
elif [ -e "$TARGET" ]; then
  fail "$TARGET exists but is not a git checkout. Move it aside or set FIGMA_CLI_DIR to another path."
else
  say "Cloning $REPO_URL into $TARGET"
  git clone --quiet --branch "$BRANCH" "$REPO_URL" "$TARGET"
fi
ok "Project is in $TARGET"

# 3. install -----------------------------------------------------------------
say "Installing dependencies (npm install)"
( cd "$TARGET" && npm install --no-fund --no-audit --silent )
ok "Dependencies installed"

# 4. hand off to Claude Code --------------------------------------------------
cat <<MSG

  figma-cli is installed in $TARGET

  Next: open Figma Desktop with a design file, then let Claude connect.
MSG

if [ -t 0 ] && command -v claude >/dev/null 2>&1 && [ -z "${FIGMA_CLI_NO_LAUNCH:-}" ]; then
  say "Claude Code found. Starting it in $TARGET"
  cd "$TARGET"
  exec claude "Set up figma-cli and connect it to my Figma. Read CLAUDE.md first."
else
  cat <<MSG
  In Terminal:
      cd "$TARGET" && claude
  then say:  connect to Figma

  (Or open the folder in Claude Desktop and say the same thing.)
  Install Claude Code if you don't have it: https://docs.claude.com/en/docs/claude-code
MSG
fi
