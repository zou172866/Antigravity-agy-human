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

normalize_path() {
  _np_in="$1"
  case "$_np_in" in
    "")
      printf '%s\n' ""
      return 0
      ;;
    "~")
      if [ -n "${HOME:-}" ]; then
        _np_in="$HOME"
      fi
      ;;
    "~/"*)
      if [ -n "${HOME:-}" ]; then
        _np_in="${HOME%/}/${_np_in#~/}"
      fi
      ;;
  esac
  case "$_np_in" in
    /*) ;;
    *)  _np_in="$(pwd)/$_np_in" ;;
  esac

  _np_out=""
  _np_rest="${_np_in#/}"
  while [ -n "$_np_rest" ]; do
    case "$_np_rest" in
      */*)
        _np_seg="${_np_rest%%/*}"
        _np_rest="${_np_rest#*/}"
        ;;
      *)
        _np_seg="$_np_rest"
        _np_rest=""
        ;;
    esac
    case "$_np_seg" in
      ""|".")
        continue
        ;;
      "..")
        case "$_np_out" in
          */*) _np_out="${_np_out%/*}" ;;
          *)   _np_out="" ;;
        esac
        ;;
      *)
        _np_out="$_np_out/$_np_seg"
        ;;
    esac
  done

  if [ -z "$_np_out" ]; then
    _np_out="/"
  fi
  printf '%s\n' "$_np_out"
}

canonicalize_path() {
  _cp_cur="$(normalize_path "$1")"
  _cp_tail=""
  while [ ! -d "$_cp_cur" ] && [ "$_cp_cur" != "/" ]; do
    _cp_base="$(basename -- "$_cp_cur")"
    if [ -n "$_cp_tail" ]; then
      _cp_tail="$_cp_base/$_cp_tail"
    else
      _cp_tail="$_cp_base"
    fi
    _cp_cur="$(dirname -- "$_cp_cur")"
  done
  if [ -d "$_cp_cur" ]; then
    _cp_cur="$(CDPATH= cd -- "$_cp_cur" && pwd -P)"
  fi
  if [ -n "$_cp_tail" ]; then
    if [ "$_cp_cur" = "/" ]; then
      printf '/%s\n' "$_cp_tail"
    else
      printf '%s/%s\n' "$_cp_cur" "$_cp_tail"
    fi
  else
    printf '%s\n' "$_cp_cur"
  fi
}

is_protected_for_home() {
  _ip_path="$1"
  _ip_home="$2"
  _ip_base="${_ip_home%/}"
  case "$_ip_path" in
    ""|"/"|"$_ip_home"|"$_ip_base/.gemini"|"$_ip_base/.gemini/config"|"$_ip_base/.gemini/config/plugins")
      return 0
      ;;
  esac
  return 1
}

NORM_HOME=""
CANON_HOME=""
if [ -n "${HOME:-}" ]; then
  NORM_HOME="$(normalize_path "$HOME")"
  if [ -d "$HOME" ]; then
    CANON_HOME="$(CDPATH= cd -- "$HOME" && pwd -P)"
  fi
fi

if [ "$CUSTOM_TARGET" -eq 0 ]; then
  if [ -z "$NORM_HOME" ]; then
    echo "Error: HOME environment variable is not set." >&2
    exit 1
  fi
  TARGET_DIR="${NORM_HOME%/}/.gemini/config/plugins/agy-clarity"
fi

TARGET_DIR="$(normalize_path "$TARGET_DIR")"
CANON_TARGET="$(canonicalize_path "$TARGET_DIR")"

if [ -z "$TARGET_DIR" ] || [ "$TARGET_DIR" = "/" ] || [ "$CANON_TARGET" = "/" ]; then
  echo "Error: Refusing to operate on protected path: $TARGET_DIR" >&2
  exit 1
fi
if [ -n "$NORM_HOME" ]; then
  if is_protected_for_home "$TARGET_DIR" "$NORM_HOME" || is_protected_for_home "$CANON_TARGET" "$NORM_HOME"; then
    echo "Error: Refusing to operate on protected path: $TARGET_DIR" >&2
    exit 1
  fi
fi
if [ -n "$CANON_HOME" ]; then
  if is_protected_for_home "$TARGET_DIR" "$CANON_HOME" || is_protected_for_home "$CANON_TARGET" "$CANON_HOME"; then
    echo "Error: Refusing to operate on protected path: $TARGET_DIR" >&2
    exit 1
  fi
fi

is_valid_plugin_source() {
  [ -d "$1" ] \
    && [ -f "$1/plugin.json" ] \
    && [ -f "$1/rules/AGENTS.md" ] \
    && [ -f "$1/skills/wait-what/SKILL.md" ]
}

if [ "$UNINSTALL" -eq 1 ]; then
  if [ ! -e "$TARGET_DIR" ] && [ ! -L "$TARGET_DIR" ]; then
    echo "[agy-clarity] Not installed at $TARGET_DIR (nothing to remove)."
    exit 0
  fi

  if [ -e "$TARGET_DIR" ] && [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Refusing to remove existing file at '$TARGET_DIR' (expected a directory)." >&2
    exit 1
  fi

  LEAF_NAME="$(basename -- "$TARGET_DIR")"
  if [ "$CUSTOM_TARGET" -eq 1 ] && [ "$LEAF_NAME" != "agy-clarity" ] && [ ! -f "$TARGET_DIR/plugin.json" ]; then
    echo "Error: Refusing to remove '$TARGET_DIR': directory is not named 'agy-clarity' and contains no plugin.json." >&2
    exit 1
  fi

  rm -rf -- "$TARGET_DIR"
  echo "[agy-clarity] Uninstalled plugin from: $TARGET_DIR"
  echo "[agy-clarity] Restart or reload your Antigravity window to apply changes."
  exit 0
fi

if [ -e "$TARGET_DIR" ] && [ ! -d "$TARGET_DIR" ]; then
  echo "Error: Refusing to overwrite existing file at '$TARGET_DIR' (expected a directory)." >&2
  exit 1
fi

TMP_DIR=""
STAGE_DIR=""
BACKUP_DIR=""
SWAP_COMPLETED=0

cleanup() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf -- "$TMP_DIR"
  fi
  if [ -n "$STAGE_DIR" ] && [ -d "$STAGE_DIR" ]; then
    rm -rf -- "$STAGE_DIR"
  fi
  if [ "$SWAP_COMPLETED" -eq 1 ] && [ -n "$BACKUP_DIR" ]; then
    if [ -e "$BACKUP_DIR" ] || [ -L "$BACKUP_DIR" ]; then
      rm -rf -- "$BACKUP_DIR"
    fi
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
      rm -rf -- "$REPO_DIR"
    fi
  fi

  if [ "$FETCHED" -eq 0 ]; then
    if ! command -v tar >/dev/null 2>&1; then
      echo "Error: git, or curl/wget with tar, is required for remote installation." >&2
      exit 1
    fi

    TAR_FILE="$TMP_DIR/agy-clarity.tar.gz"
    DOWNLOADED=0

    if command -v curl >/dev/null 2>&1; then
      echo "[agy-clarity] Downloading archive from GitHub via curl..."
      if curl -fsSL -o "$TAR_FILE" "$REPO_TAR_URL"; then
        DOWNLOADED=1
      else
        rm -f -- "$TAR_FILE"
      fi
    fi

    if [ "$DOWNLOADED" -eq 0 ] && command -v wget >/dev/null 2>&1; then
      echo "[agy-clarity] Downloading archive from GitHub via wget..."
      if wget -qO "$TAR_FILE" "$REPO_TAR_URL"; then
        DOWNLOADED=1
      else
        rm -f -- "$TAR_FILE"
      fi
    fi

    if [ "$DOWNLOADED" -eq 0 ]; then
      echo "Error: Failed to download agy-clarity archive (curl or wget required)." >&2
      exit 1
    fi

    EXTRACT_DIR="$TMP_DIR/extract"
    mkdir -p -- "$EXTRACT_DIR"
    tar -xzf "$TAR_FILE" -C "$EXTRACT_DIR"

    if is_valid_plugin_source "$EXTRACT_DIR"; then
      SRC_DIR="$EXTRACT_DIR"
      FETCHED=1
    else
      for cand in "$EXTRACT_DIR"/*; do
        if is_valid_plugin_source "$cand"; then
          SRC_DIR="$cand"
          FETCHED=1
          break
        fi
      done
    fi

    if [ "$FETCHED" -eq 0 ]; then
      echo "Error: Failed to locate valid agy-clarity files inside downloaded archive." >&2
      exit 1
    fi
  fi
fi

if ! is_valid_plugin_source "$SRC_DIR"; then
  echo "Error: Invalid agy-clarity source directory: $SRC_DIR" >&2
  exit 1
fi

CANON_SRC="$(CDPATH= cd -- "$SRC_DIR" && pwd -P)"
if [ "$CANON_SRC" = "$CANON_TARGET" ]; then
  echo "[agy-clarity] Plugin is already installed in place at: $TARGET_DIR"
  echo "[agy-clarity] Restart or reload your Antigravity window if not yet loaded."
  exit 0
fi

case "$CANON_SRC" in
  "$CANON_TARGET"/*)
    echo "Error: Refusing to install into ancestor directory '$TARGET_DIR' of source '$SRC_DIR'." >&2
    exit 1
    ;;
esac

case "$CANON_TARGET" in
  "$CANON_SRC"/*)
    echo "Error: Refusing to install into subdirectory '$TARGET_DIR' inside source '$SRC_DIR'." >&2
    exit 1
    ;;
esac

PARENT_DIR="$(dirname -- "$TARGET_DIR")"
mkdir -p -- "$PARENT_DIR"

STAGE_DIR="$(mktemp -d "$PARENT_DIR/.agy-clarity-stage.XXXXXX" 2>/dev/null || true)"
if [ -z "$STAGE_DIR" ]; then
  STAGE_DIR="$PARENT_DIR/.agy-clarity-stage.$$"
  rm -rf -- "$STAGE_DIR"
  mkdir -p -- "$STAGE_DIR"
fi

for entry in "$SRC_DIR"/* "$SRC_DIR"/.[!.]* "$SRC_DIR"/..?*; do
  if [ ! -e "$entry" ] && [ ! -L "$entry" ]; then
    continue
  fi
  base="$(basename -- "$entry")"
  if [ "$base" = ".git" ]; then
    continue
  fi
  cp -R -- "$entry" "$STAGE_DIR/$base"
done

rm -rf -- "$STAGE_DIR/.git"

if ! is_valid_plugin_source "$STAGE_DIR"; then
  echo "Error: Staged plugin bundle failed integrity check." >&2
  exit 1
fi

if [ -e "$TARGET_DIR" ] || [ -L "$TARGET_DIR" ]; then
  BACKUP_DIR="$PARENT_DIR/.agy-clarity-backup.$$"
  rm -rf -- "$BACKUP_DIR"
  mv -- "$TARGET_DIR" "$BACKUP_DIR"
fi

if ! mv -- "$STAGE_DIR" "$TARGET_DIR"; then
  if [ -n "$BACKUP_DIR" ]; then
    if [ -e "$BACKUP_DIR" ] || [ -L "$BACKUP_DIR" ]; then
      if [ ! -e "$TARGET_DIR" ] && [ ! -L "$TARGET_DIR" ]; then
        mv -- "$BACKUP_DIR" "$TARGET_DIR" || true
      fi
    fi
  fi
  echo "Error: Failed to move staged plugin into $TARGET_DIR" >&2
  exit 1
fi

SWAP_COMPLETED=1
if [ -n "$BACKUP_DIR" ]; then
  if [ -e "$BACKUP_DIR" ] || [ -L "$BACKUP_DIR" ]; then
    rm -rf -- "$BACKUP_DIR"
  fi
fi

echo "[agy-clarity] Installed successfully to: $TARGET_DIR"
echo "[agy-clarity] Included: rules/AGENTS.md (always-on) and skills/wait-what/SKILL.md (on-demand)."
echo "[agy-clarity] config.json was not modified. Restart or reload your Antigravity window to activate."
