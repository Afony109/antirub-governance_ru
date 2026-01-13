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

# Клонируем именно target repo
git clone "https://x-access-token:${TOKEN}@github.com/${TARGET_REPO}.git" "${WORKDIR}"

# Проверка: это точно git-репозиторий
git -C "${WORKDIR}" rev-parse --is-inside-work-tree >/dev/null

# Для дополнительной уверенности: origin должен быть TARGET_REPO
ORIGIN_URL="$(git -C "${WORKDIR}" remote get-url origin)"
echo "Origin: ${ORIGIN_URL}"
case "${ORIGIN_URL}" in
  *"${TARGET_REPO}.git"*) ;;
  *) echo "ERROR: origin is not target repo (${TARGET_REPO}). Aborting."; exit 1;;
esac

# Создаём/сбрасываем ветку
git -C "${WORKDIR}" checkout -B "${BRANCH}"

# Синхронизация файлов перевода в корень target repo
# (исключаем .git, чтобы не сломать репозиторий)
rsync -a --delete \
  --exclude ".git/" \
  "${SRC_DIR}/" "${WORKDIR}/"

# Коммитим только если есть изменения
git -C "${WORKDIR}" add -A

if git -C "${WORKDIR}" diff --cached --quiet; then
  echo "No changes to commit for ${TARGET_REPO}"
  exit 0
fi

git -C "${WORKDIR}" -c user.name="ru-translate-bot" \
  -c user.email="ru-translate-bot@users.noreply.github.com" \
  commit -m "[bot-translate] sync from ru"

# Пушим ветку в target repo
git -C "${WORKDIR}" push -f origin "${BRANCH}"

echo "Done: ${TARGET_REPO} (${LANG})"
