#!/usr/bin/env bash
set -euo pipefail

# --- required env ---
: "${TOKEN:?Missing TOKEN}"
: "${TARGET_REPO:?Missing TARGET_REPO}"
: "${LANG:?Missing LANG}"

# --- config ---
BRANCH="bot/translate-from-ru"
WORKDIR="target_${LANG}"
SRC_DIR="out/${LANG}"

echo "Pushing translations to ${TARGET_REPO} (${LANG})"

# clean previous workdir
rm -rf "$WORKDIR"

# --- clone with GitHub App token ---
git clone "https://x-access-token:${TOKEN}@github.com/${TARGET_REPO}.git" "$WORKDIR"

cd "$WORKDIR"

# create/reset branch
git checkout -B "$BRANCH"

# --- replace repo content with translated files ---
cd ..
shopt -s dotglob
for item in "$WORKDIR"/* "$WORKDIR"/.*; do
  base="$(basename "$item")"
  [[ "$base" == "." || "$base" == ".." || "$base" == ".git" ]] && continue
  rm -rf "$item"
done
shopt -u dotglob

rsync -a --delete "${SRC_DIR}/" "${WORKDIR}/"

cd "$WORKDIR"

# --- commit if there are changes ---
git add -A

if git diff --cached --quiet; then
  echo "No changes to commit for ${TARGET_REPO}"
  exit 0
fi

git -c user.name="ru-translate-bot" \
    -c user.email="ru-translate-bot@users.noreply.github.com" \
    commit -m "[bot-translate] sync from ru"

# --- push branch ---
git push -f origin "$BRANCH"

echo "Done: ${TARGET_REPO}"
