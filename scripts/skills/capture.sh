#!/usr/bin/env bash
# capture.sh — создать capture по одному из 7 направлений Note-Review (PD.FORM.005)
#
# Использование:
#   capture.sh "Тема" "Источник" ["Контекст"]
#   capture.sh --type <тип> "Тема" "Источник" ["Контекст"]
#
# Типы (7 направлений FMT):
#   capture       — доменное знание → ds-knowledge-index/captures/
#   draft         — зерно для поста → ds-knowledge-index/drafts/ + draft-list.md
#   distinction   — различение → iwe-platform/memory/distinctions.md
#   dissatisfaction — НЭП → ds-strategy/docs/Dissatisfactions.md
#   task          — задача → WeekPlan/DayPlan (через wp-new.sh или строкой)
#   idea          — идея без действия → ds-strategy/inbox/fleeting-notes.md
#   personal      — личные данные → ds-knowledge-index/personal/
#   noise         — шум → /dev/null (архив)
#
# Примеры:
#   capture.sh "Принципы FinOps" "webinar" "облачная архитектура"
#   capture.sh --type draft "Почему ИИ-агенты не заменят архитектора" "личный опыт"
#   capture.sh --type distinction "Gap покрытия vs Gap исполнения" "WP-25"
#   capture.sh --type dissatisfaction "Слишком много captures без движения" "Н14"

set -euo pipefail

# --- Config ---
KNOWLEDGE_INDEX="${HOME}/ds-knowledge-index"
IWE_PLATFORM="${HOME}/iwe-platform"
DS_STRATEGY="${HOME}/ds-strategy"

CAPTURE_DIR="${KNOWLEDGE_INDEX}/captures"
DRAFT_DIR="${KNOWLEDGE_INDEX}/drafts"
PERSONAL_DIR="${KNOWLEDGE_INDEX}/personal"
DISTINCTIONS_FILE="${IWE_PLATFORM}/memory/distinctions.md"
DISSATISFACTIONS_FILE="${DS_STRATEGY}/docs/Dissatisfactions.md"
FLEETING_NOTES="${DS_STRATEGY}/inbox/fleeting-notes.md"
DRAFT_LIST="${DS_STRATEGY}/drafts/draft-list.md"

# --- Args ---
TYPE="capture"
TOPIC=""
SOURCE=""
CONTEXT=""

if [[ "${1:-}" == "--type" ]]; then
    TYPE="${2:-capture}"
    shift 2
fi

TOPIC="${1:-}"
SOURCE="${2:-}"
CONTEXT="${3:-}"

if [[ -z "${TOPIC}" ]]; then
    echo "Использование: capture.sh [--type <тип>] \"Тема\" \"Источник\" [\"Контекст\"]"
    echo ""
    echo "7 направлений Note-Review (PD.FORM.005):"
    echo "  capture         — доменное знание → ds-knowledge-index/captures/"
    echo "  draft           — зерно для поста → ds-knowledge-index/drafts/"
    echo "  distinction     — различение → iwe-platform/memory/distinctions.md"
    echo "  dissatisfaction — НЭП → ds-strategy/docs/Dissatisfactions.md"
    echo "  task            — задача → WeekPlan/DayPlan (через wp-new.sh)"
    echo "  idea            — идея без действия → ds-strategy/inbox/fleeting-notes.md"
    echo "  personal        — личные данные → ds-knowledge-index/personal/"
    echo "  noise           — шум → /dev/null (архив)"
    echo ""
    echo "Примеры:"
    echo "  capture.sh --type draft \"Почему агенты не заменят архитектора\" \"опыт\""
    echo "  capture.sh --type dissatisfaction \"Captures без движения\" \"Н14\""
    echo "  capture.sh --type idea \"Может ли Pack быть локальным\""
    exit 1
fi

# --- Helpers ---
slugify() {
    echo "$1" | perl -CS -pe '$_ = lc; s/[^\p{L}\p{N}]+/-/g; s/^-|-$//g'
    return 0
}

DATE=$(date +%Y-%m-%d)

# --- Routing ---
case "${TYPE}" in
    capture)
        SLUG=$(slugify "${TOPIC}")
        [ -z "${SLUG}" ] && SLUG="capture"
        FILENAME="${DATE}-${SLUG}.md"
        FILEPATH="${CAPTURE_DIR}/${FILENAME}"

        mkdir -p "${CAPTURE_DIR}"

        cat > "${FILEPATH}" << EOF
## ${DATE}: ${TOPIC}

**Что узнал:** 
**Откуда:** ${SOURCE}
**Контекст:** ${CONTEXT}

---

*Capture · ds-knowledge-index · TTL=∞ (до Pack)*
EOF
        echo "✅ Capture создан: ${FILEPATH}"
        ;;

    draft)
        SLUG=$(slugify "${TOPIC}")
        [ -z "${SLUG}" ] && SLUG="draft"
        FILENAME="${DATE}-${SLUG}.md"
        FILEPATH="${DRAFT_DIR}/${FILENAME}"

        mkdir -p "${DRAFT_DIR}"

        cat > "${FILEPATH}" << EOF
# ${TOPIC}

**Дата:** ${DATE}
**Источник:** ${SOURCE}
**Контекст:** ${CONTEXT}
**TTL:** ${DATE} + 7d = $(date -j -v+7d +%Y-%m-%d 2>/dev/null || date -d "+7 days" +%Y-%m-%d)

---

EOF
        echo "✅ Черновик создан: ${FILEPATH}"

        # Register in draft-list.md
        mkdir -p "$(dirname "${DRAFT_LIST}")"
        if [ ! -f "${DRAFT_LIST}" ]; then
            cat > "${DRAFT_LIST}" << 'LISTEOF'
# Draft List — индекс черновиков

> **Формат:** статус · дата · заголовок · TTL
> **Guard:** ≤5 active (6—10 ⚠️, >10 🚫 блокировка)
> **Источник:** PD.FORM.005 Creative Pipeline

| Статус | Дата | Заголовок | TTL |
|--------|------|-----------|-----|
LISTEOF
        fi

        # Add entry if not already present
        if ! grep -qF "${TOPIC}" "${DRAFT_LIST}" 2>/dev/null; then
            echo "| draft | ${DATE} | ${TOPIC} | $(date -j -v+7d +%Y-%m-%d 2>/dev/null || date -d "+7 days" +%Y-%m-%d) |" >> "${DRAFT_LIST}"
        fi
        ;;

    distinction)
        ENTRY="- **${TOPIC}** — ${SOURCE}"

        if ! grep -qF "${ENTRY}" "${DISTINCTIONS_FILE}" 2>/dev/null; then
            if grep -q "^---$" "${DISTINCTIONS_FILE}"; then
                sed -i '' "/^---$/i\\
${ENTRY}\\
" "${DISTINCTIONS_FILE}"
            else
                echo "${ENTRY}" >> "${DISTINCTIONS_FILE}"
            fi
            echo "✅ Различение добавлено в: ${DISTINCTIONS_FILE}"
        else
            echo "⚠️  Различение уже существует в distinctions.md"
        fi
        ;;

    dissatisfaction)
        ENTRY="- **[${DATE}]** ${TOPIC} — ${SOURCE}"

        if ! grep -qF "${TOPIC}" "${DISSATISFACTIONS_FILE}" 2>/dev/null; then
            echo "${ENTRY}" >> "${DISSATISFACTIONS_FILE}"
            echo "✅ НЭП добавлен в: ${DISSATISFACTIONS_FILE}"
        else
            echo "⚠️  НЭП с такой темой уже существует в Dissatisfactions.md"
        fi
        ;;

    task)
        echo "📋 Задача: «${TOPIC}»"
        echo "   Источник: ${SOURCE}"
        echo "   Контекст: ${CONTEXT}"
        echo ""
        echo "   → Для быстрого создания РП используй: scripts/skills/wp-new.sh"
        echo "   → Для добавления в DayPlan отредактируй: ~/ds-strategy/current/DayPlan.md"
        echo "   → Для добавления в WeekPlan отредактируй: ~/ds-strategy/current/WeekPlan.md"
        ;;

    idea)
        ENTRY="- [$(date +%H:%M)] 💡 ${TOPIC}"

        if ! grep -qF "${TOPIC}" "${FLEETING_NOTES}" 2>/dev/null; then
            echo "${ENTRY}" >> "${FLEETING_NOTES}"
            echo "✅ Идея добавлена в: ${FLEETING_NOTES}"
        else
            echo "⚠️  Идея уже существует в fleeting-notes.md"
        fi
        echo "   (вернуться на стратегической сессии)"
        ;;

    personal)
        SLUG=$(slugify "${TOPIC}")
        [ -z "${SLUG}" ] && SLUG="personal"
        FILENAME="${DATE}-${SLUG}.md"
        FILEPATH="${PERSONAL_DIR}/${FILENAME}"

        mkdir -p "${PERSONAL_DIR}"

        cat > "${FILEPATH}" << EOF
# ${TOPIC}

**Дата:** ${DATE}
**Источник:** ${SOURCE}
**Контекст:** ${CONTEXT}

---

EOF
        echo "✅ Личная запись создана: ${FILEPATH}"
        ;;

    noise)
        echo "🗑️  Шум — не сохраняется. Тема: «${TOPIC}»"
        ;;

    *)
        echo "❌ Неизвестный тип: ${TYPE}"
        echo "   Допустимые: capture, draft, distinction, dissatisfaction, task, idea, personal, noise"
        exit 1
        ;;
esac
