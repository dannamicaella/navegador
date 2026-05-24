#!/usr/bin/env bash
set -euo pipefail

RAW_BASE_URL="${RAW_BASE_URL:-https://raw.githubusercontent.com/giovannefeitosa/navegador/main}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR=""

cleanup() {
  if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}
trap cleanup EXIT

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Comando obrigatorio ausente: $1" >&2
    exit 1
  }
}

need_cmd powershell.exe
need_cmd curl
need_cmd wslpath

TMP_DIR="$(mktemp -d)"
LOCAL_PS1="${SCRIPT_DIR}/install-navegador.ps1"
LOCAL_SKILL="${SCRIPT_DIR}/../skills/navegador/SKILL.md"
PS1_PATH="${LOCAL_PS1}"
SKILL_PATH="${LOCAL_SKILL}"

if [[ ! -f "${PS1_PATH}" ]]; then
  PS1_PATH="${TMP_DIR}/install-navegador.ps1"
  curl -fsSL "${RAW_BASE_URL}/scripts/install-navegador.ps1" -o "${PS1_PATH}"
fi

if [[ ! -f "${SKILL_PATH}" ]]; then
  SKILL_PATH="${TMP_DIR}/SKILL.md"
  curl -fsSL "${RAW_BASE_URL}/skills/navegador/SKILL.md" -o "${SKILL_PATH}"
fi

for base in "$HOME/.codex/skills" "$HOME/.claude/skills"; do
  if [[ -d "${base}" ]]; then
    mkdir -p "${base}/navegador"
    cp "${SKILL_PATH}" "${base}/navegador/SKILL.md"
  fi
done

PS1_WIN="$(wslpath -w "${PS1_PATH}")"
SKILL_WIN="$(wslpath -w "${SKILL_PATH}")"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${PS1_WIN}" -SkillSourcePath "${SKILL_WIN}"
