#!/usr/bin/env sh
# Zero-dependency POSIX installer/uninstaller for agy-clarity (Google Antigravity plugin).
# Supports both `curl -fsSL https://raw.githubusercontent.com/zou172866/Antigravity-agy-clarity/main/install.sh | sh`
# and local repository runs (`sh ./install.sh`, `sh ./install.sh --uninstall`).
set -eu

REPO_SLUG="zou172866/Antigravity-agy-clarity"
REPO_GIT_URL="https://github.com/$REPO_SLUG.git"
REPO_TAR_URL="https://github.com/$REPO_SLUG/archive/refs/heads/main.tar.gz"

UNINSTALL=0
CUSTOM_TARGET=0
TARGET_DIR=""

usage() {
  cat <<'EOF'
Usage: install.sh [OPTIONS]

Options:
  --uninstall       Remove the installed agy-clarity plugin directory
  --target DIR      Install or uninstall at a custom directory
  -h, --help        Show this help message
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --uninstall)
      UNINSTALL=1
      shift
      ;;
    --target)
      if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
        echo "Error: --target requires a non-empty directory path." >&2
        exit 1
      fi
      TARGET_DIR="$2"
      CUSTOM_TARGET=1
      shift 2
      ;;
    --target=*)
      TARGET_DIR="${1#--target=}"
      if [ -z "$TARGET_DIR" ]; then
        echo "Error: --target requires a non-empty directory path." >&2
        exit 1
      fi
      CUSTOM_TARGET=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown option '$1'." >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ "$CUSTOM_TARGET" -eq 0 ]; then
  if [ -z "${HOME:-}" ]; then
    echo "Error: HOME environment variable is not set." >&2
    exit 1
  fi
  TARGET_DIR="$HOME/.gemini/config/plugins/agy-clarity"
fi

# Strip trailing slashes (preserve single "/")
while [ "$TARGET_DIR" != "/" ] && [ "${TARGET_DIR%/}" != "$TARGET_DIR" ]; do
  TARGET_DIR="${TARGET_DIR%/}"
done

case "$TARGET_DIR" in
  ""|"/"|"${HOME:-}"|"${HOME:-}/.gemini"|"${HOME:-}/.gemini/config"|"${HOME:-}/.gemini/config/plugins")
    echo "Error: Refusing to operate on protected path: $TARGET_DIR" >&2
    exit 1
    ;;
esac

is_valid_plugin_source() {
  [ -d "$1" ] \
    && [ -f "$1/plugin.json" ] \
    && [ -f "$1/rules/AGENTS.md" ] \
    && [ -f "$1/skills/wait-what/SKILL.md" ]
}

if [ "$UNINSTALL" -eq 1 ]; then
  if [ ! -e "$TARGET_DIR" ]; then
    echo "[agy-clarity] Not installed at $TARGET_DIR (nothing to remove)."
    exit 0
  fi

  LEAF_NAME="$(basename -- "$TARGET_DIR")"
  if [ "$CUSTOM_TARGET" -eq 1 ] && [ "$LEAF_NAME" != "agy-clarity" ] && [ ! -f "$TARGET_DIR/plugin.json" ]; then
    echo "Error: Refusing to remove '$TARGET_DIR': directory is not named 'agy-clarity' and contains no plugin.json." >&2
    exit 1
  fi

  rm -rf "$TARGET_DIR"
  echo "[agy-clarity] Uninstalled plugin from: $TARGET_DIR"
  echo "[agy-clarity] Restart or reload your Antigravity window to apply changes."
  exit 0
fi

TMP_DIR=""
STAGE_DIR=""
BACKUP_DIR=""
SWAP_COMPLETED=0

cleanup() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
  if [ -n "$STAGE_DIR" ] && [ -d "$STAGE_DIR" ]; then
    rm -rf "$STAGE_DIR"
  fi
  if [ "$SWAP_COMPLETED" -eq 1 ] && [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
    rm -rf "$BACKUP_DIR"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

SCRIPT_DIR=""
if [ -n "${0:-}" ] && [ -f "$0" ]; then
  case "$0" in
    */*) CANDIDATE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)" ;;
    *)   CANDIDATE_DIR="$(pwd)" ;;
  esac
  if is_valid_plugin_source "$CANDIDATE_DIR"; then
    SCRIPT_DIR="$CANDIDATE_DIR"
  fi
fi

SRC_DIR=""
if [ -n "$SCRIPT_DIR" ]; then
  SRC_DIR="$SCRIPT_DIR"
  echo "[agy-clarity] Installing from local repository: $SRC_DIR"
else
  TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t 'agy-clarity-install')"
  REPO_DIR="$TMP_DIR/repo"
  FETCHED=0

  if command -v git >/dev/null 2>&1; then
    echo "[agy-clarity] Fetching latest release from GitHub via git..."
    if git clone --depth 1 --quiet "$REPO_GIT_URL" "$REPO_DIR" && is_valid_plugin_source "$REPO_DIR"; then
      SRC_DIR="$REPO_DIR"
      FETCHED=1
    else
      rm -rf "$REPO_DIR"
    fi
  fi

  if [ "$FETCHED" -eq 0 ]; then
    if command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
      echo "[agy-clarity] Downloading archive from GitHub via curl..."
      mkdir -p "$REPO_DIR"
      curl -fsSL "$REPO_TAR_URL" | tar -xz --strip-components=1 -C "$REPO_DIR"
      SRC_DIR="$REPO_DIR"
      FETCHED=1
    elif command -v wget >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
      echo "[agy-clarity] Downloading archive from GitHub via wget..."
      mkdir -p "$REPO_DIR"
      wget -qO- "$REPO_TAR_URL" | tar -xz --strip-components=1 -C "$REPO_DIR"
      SRC_DIR="$REPO_DIR"
      FETCHED=1
    else
      echo "Error: git, or curl/wget with tar, is required for remote installation." >&2
      exit 1
    fi
  fi
fi

if ! is_valid_plugin_source "$SRC_DIR"; then
  echo "Error: Invalid agy-clarity source directory: $SRC_DIR" >&2
  exit 1
fi

if [ -d "$TARGET_DIR" ]; then
  CANON_SRC="$(CDPATH= cd -- "$SRC_DIR" && pwd -P)"
  CANON_TGT="$(CDPATH= cd -- "$TARGET_DIR" && pwd -P)"
  if [ "$CANON_SRC" = "$CANON_TGT" ]; then
    echo "[agy-clarity] Plugin is already installed in place at: $TARGET_DIR"
    echo "[agy-clarity] Restart or reload your Antigravity window if not yet loaded."
    exit 0
  fi
fi

PARENT_DIR="$(dirname -- "$TARGET_DIR")"
mkdir -p "$PARENT_DIR"

STAGE_DIR="$(mktemp -d "$PARENT_DIR/.agy-clarity-stage.XXXXXX" 2>/dev/null || true)"
if [ -z "$STAGE_DIR" ]; then
  STAGE_DIR="$PARENT_DIR/.agy-clarity-stage.$$"
  rm -rf "$STAGE_DIR"
  mkdir -p "$STAGE_DIR"
fi

for entry in "$SRC_DIR"/* "$SRC_DIR"/.[!.]* "$SRC_DIR"/..?*; do
  if [ ! -e "$entry" ] && [ ! -L "$entry" ]; then
    continue
  fi
  base="$(basename -- "$entry")"
  if [ "$base" = ".git" ]; then
    continue
  fi
  cp -R "$entry" "$STAGE_DIR/$base"
done

rm -rf "$STAGE_DIR/.git"

if ! is_valid_plugin_source "$STAGE_DIR"; then
  echo "Error: Staged plugin bundle failed integrity check." >&2
  exit 1
fi

if [ -e "$TARGET_DIR" ]; then
  BACKUP_DIR="$PARENT_DIR/.agy-clarity-backup.$$"
  rm -rf "$BACKUP_DIR"
  mv "$TARGET_DIR" "$BACKUP_DIR"
fi

if ! mv "$STAGE_DIR" "$TARGET_DIR"; then
  if [ -n "$BACKUP_DIR" ] && [ -e "$BACKUP_DIR" ] && [ ! -e "$TARGET_DIR" ]; then
    mv "$BACKUP_DIR" "$TARGET_DIR" || true
  fi
  echo "Error: Failed to move staged plugin into $TARGET_DIR" >&2
  exit 1
fi

SWAP_COMPLETED=1
if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
  rm -rf "$BACKUP_DIR"
fi

echo "[agy-clarity] Installed successfully to: $TARGET_DIR"
echo "[agy-clarity] Included: rules/AGENTS.md (always-on) and skills/wait-what/SKILL.md (on-demand)."
echo "[agy-clarity] config.json was not modified. Restart or reload your Antigravity window to activate."
