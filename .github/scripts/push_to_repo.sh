#!/usr/bin/env bash
set -euo pipefail

: "${TOKEN:?Missing TOKEN}"
: "${TARGET_REPO:?Missing TARGET_REPO}"
: "${LANG:?Missing LANG}"

BRANCH="bot/translate-from-ru"
WORKDIR="target_${LANG}"
SRC_DIR="out/${LANG}"

echo "Pushing translations to ${TARGET_REPO} (${LANG})"

rm -rf "${WORKDIR}"

# Clone target repo using GitHub App installation token
git clone "https://x-access-token:${TOKEN}@github.com/${TARGET_REPO}.git" "${WORKDIR}"

# Sanity check: ensure it's a git work tree
git -C "${WORKDIR}" rev-parse --is-inside-work-tree >/dev/null

# Extra safety: verify origin is the intended target repo
ORIGIN_URL="$(git -C "${WORKDIR}" remote get-url origin)"
echo "Origin: ${ORIGIN_URL}"
case "${ORIGIN_URL}" in
  *"${TARGET_REPO}.git"*) ;;
  *) echo "ERROR: origin is not target repo (${TARGET_REPO}). Aborting."; exit 1;;
esac

# Fetch existing remote branch if it exists (avoid force-push)
git -C "${WORKDIR}" fetch origin "${BRANCH}" || true

if git -C "${WORKDIR}" show-ref --verify --quiet "refs/remotes/origin/${BRANCH}"; then
  git -C "${WORKDIR}" checkout -B "${BRANCH}" "origin/${BRANCH}"
else
  git -C "${WORKDIR}" checkout -B "${BRANCH}"
fi

# SAFE SYNC: copy translations on top, DO NOT delete anything in target repo
# - no --delete
# - exclude internal git dir
# Optional: exclude folders you never want to touch while testing
rsync -a \
  --exclude ".git/" \
  --exclude ".github/" \
  --exclude "ledger/" \
  --exclude ".gitattributes" \
  "${SRC_DIR}/" "${WORKDIR}/"

# Stage changes
git -C "${WORKDIR}" add -A

# Exit if no changes
if git -C "${WORKDIR}" diff --cached --quiet; then
  echo "No changes to commit for ${TARGET_REPO}"
  exit 0
fi

# Commit
git -C "${WORKDIR}" -c user.name="ru-translate-bot" \
  -c user.email="ru-translate-bot@users.noreply.github.com" \
  commit -m "[bot-translate] sync from ru"

# Push WITHOUT force
git -C "${WORKDIR}" push -u origin "${BRANCH}"

echo "Done: ${TARGET_REPO} (${LANG})"
