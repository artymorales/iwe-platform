#!/usr/bin/env bash
# capture.sh — создать capture-файл в knowledge-index по шаблону work.md §2
#
# Использование:
#   capture.sh "Тема" "Источник" ["Контекст"]
#   capture.sh --type draft "Тема" "Источник"
#   capture.sh --type distinction "Название различения" "Контекст"
#
# Примеры:
#   capture.sh "Проблематизация через эпистема/система" "ailev.livejournal.com/1803425.html" "IWE-проект, сессия WP-9"
#   capture.sh --type distinction "Gap покрытия vs Gap исполнения" "WP-25, Day Open Gate"
#
# Куда пишет:
#   captures/ → ~/ds-knowledge-index/captures/YYYY-MM-DD-slug.md
#   drafts/   → ~/ds-knowledge-index/drafts/YYYY-MM-DD-slug.md
#   distinctions → ~/iwe-platform/memory/distinctions.md (дописывает строку)

set -euo pipefail

# --- Config ---
KNOWLEDGE_INDEX="${HOME}/ds-knowledge-index"
IWE_PLATFORM="${HOME}/iwe-platform"
CAPTURE_DIR="${KNOWLEDGE_INDEX}/captures"
DRAFT_DIR="${KNOWLEDGE_INDEX}/drafts"
DISTINCTIONS_FILE="${IWE_PLATFORM}/memory/distinctions.md"

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
    echo "Использование: capture.sh [--type capture|draft|distinction] \"Тема\" \"Источник\" [\"Контекст\"]"
    echo ""
    echo "Типы:"
    echo "  capture     — доменное знание → ds-knowledge-index/captures/"
    echo "  draft       — сырая мысль → ds-knowledge-index/drafts/"
    echo "  distinction — правило/различение → iwe-platform/memory/distinctions.md"
    exit 1
fi

# --- Routing ---
case "${TYPE}" in
    capture)
        DATE=$(date +%Y-%m-%d)
        # Generate a safe filename slug (keeps Unicode letters/numbers)
        SLUG=$(echo "${TOPIC}" | perl -CS -pe '$_ = lc; s/[^\p{L}\p{N}]+/-/g; s/^-|-$//g')
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

*Capture · WP- · ds-knowledge-index*
EOF
        echo "✅ Capture создан: ${FILEPATH}"
        ;;

    draft)
        DATE=$(date +%Y-%m-%d)
        # Generate a safe filename slug (keeps Unicode letters/numbers)
        SLUG=$(echo "${TOPIC}" | perl -CS -pe '$_ = lc; s/[^\p{L}\p{N}]+/-/g; s/^-|-$//g')
        [ -z "${SLUG}" ] && SLUG="draft"
        FILENAME="${DATE}-${SLUG}.md"
        FILEPATH="${DRAFT_DIR}/${FILENAME}"

        mkdir -p "${DRAFT_DIR}"

        cat > "${FILEPATH}" << EOF
# ${TOPIC}

**Дата:** ${DATE}
**Источник:** ${SOURCE}
**Контекст:** ${CONTEXT}

---

EOF
        echo "✅ Черновик создан: ${FILEPATH}"
        ;;

    distinction)
        TIMESTAMP=$(date +%Y-%m-%d)
        ENTRY="- **${TOPIC}** — ${SOURCE}"

        if ! grep -qF "${ENTRY}" "${DISTINCTIONS_FILE}" 2>/dev/null; then
            # Insert after the last distinction entry (before the closing --- if any)
            if grep -q "^---$" "${DISTINCTIONS_FILE}"; then
                # Insert before the last ---
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

    *)
        echo "❌ Неизвестный тип: ${TYPE}"
        echo "   Допустимые: capture, draft, distinction"
        exit 1
        ;;
esac
