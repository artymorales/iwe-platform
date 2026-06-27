#!/usr/bin/env bash
# creative-pipeline.sh — проверка и продвижение по творческому конвейеру
#
# Источник: PD.FORM.005 Creative Pipeline (FMT/IWE)
# Адаптация: Pi Agent + Aethon (без launchd, без R2 экстрактора)
#
# Операции:
#   check             — TTL-проверка + guard check + статистика конвейера
#   promote-to-pack   — продвинуть capture в локальный Pack
#   promote-draft     — продвинуть черновик → published
#   resolve-captures  — интерактивный разбор captures (7 направлений)
#
# Использование:
#   creative-pipeline.sh check
#   creative-pipeline.sh promote-to-pack <capture-file>
#   creative-pipeline.sh promote-draft <draft-file>
#   creative-pipeline.sh resolve-captures

set -euo pipefail

# --- Config ---
KNOWLEDGE_INDEX="${HOME}/ds-knowledge-index"
DS_STRATEGY="${HOME}/ds-strategy"
IWE_PLATFORM="${HOME}/iwe-platform"

CAPTURE_DIR="${KNOWLEDGE_INDEX}/captures"
DRAFT_DIR="${KNOWLEDGE_INDEX}/drafts"
PACKS_DIR="${KNOWLEDGE_INDEX}/packs"
PUBLISHED_DIR="${KNOWLEDGE_INDEX}/published"
DRAFT_LIST="${DS_STRATEGY}/drafts/draft-list.md"
FLEETING_NOTES="${DS_STRATEGY}/inbox/fleeting-notes.md"

# --- TTL constants (days) ---
TTL_FLEETING=7
TTL_DRAFT=7
TTL_STAGING=14

CMD="${1:-}"

usage() {
    echo "Творческий конвейер — PD.FORM.005"
    echo ""
    echo "Использование:"
    echo "  creative-pipeline.sh check"
    echo "  creative-pipeline.sh promote-to-pack <capture-file> [domain]"
    echo "  creative-pipeline.sh promote-draft <draft-file>"
    echo "  creative-pipeline.sh resolve-captures"
    echo ""
    echo "Операции:"
    echo "  check            — статистика, TTL, guard check"
    echo "  promote-to-pack  — capture → packs/<domain>/"
    echo "  promote-draft    — draft → published/ + обновить draft-list"
    echo "  resolve-captures — интерактивный разбор captures по 7 направлениям"
    exit 1
}

[ -z "${CMD}" ] && usage

# --- Helpers ---
days_old() {
    # Returns how many days old a file is
    local file="$1"
    local file_date
    file_date=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo 0)
    local now
    now=$(date +%s)
    echo $(( (now - file_date) / 86400 ))
}

# --- check ---
check() {
    echo "═══════════════════════════════════════════"
    echo "  ТВОРЧЕСКИЙ КОНВЕЙЕР — ПРОВЕРКА"
    echo "═══════════════════════════════════════════"
    echo ""

    # Captures
    local n_captures
    n_captures=$(find "${CAPTURE_DIR}" -name "*.md" -type f 2>/dev/null | wc -l | tr -d '[:space:]')
    echo "📁 Captures: ${n_captures}"

    # Stale captures (>30 days — heuristic, captures don't have strict TTL)
    local stale_captures=0
    shopt -s nullglob 2>/dev/null || true
    for f in "${CAPTURE_DIR}"/*.md; do
        [ -f "$f" ] || continue
        if [ "$(days_old "$f")" -gt 30 ]; then
            ((stale_captures++)) || true
        fi
    done
    if [ "${stale_captures}" -gt 0 ]; then
        echo "   ⚠️  ${stale_captures} capture(ов) старше 30 дней — пора разобрать (resolve-captures)"
    fi

    # Drafts
    local n_drafts=0
    if [ -f "${DRAFT_LIST}" ]; then
        n_drafts=$(grep -c "^| draft " "${DRAFT_LIST}" 2>/dev/null || echo 0)
        n_drafts=$(echo "${n_drafts}" | head -1)
    fi
    echo "📝 Черновики (drafts): ${n_drafts}"
    echo ""

    # Guard check
    if [ "${n_drafts}" -le 5 ]; then
        echo "   ✅ Guard: норма (≤5)"
    elif [ "${n_drafts}" -le 10 ]; then
        echo "   ⚠️  Guard: предупреждение (${n_drafts}/10) — приоритизируй или закрой"
    else
        echo "   🚫 Guard: БЛОКИРОВКА (${n_drafts} > 10) — нельзя добавлять новые черновики!"
    fi

    # TTL check — stale drafts
    if [ -f "${DRAFT_LIST}" ]; then
        echo ""
        echo "TTL-проверка черновиков:"
        local violations=0
        while IFS= read -r line; do
            # Parse: | draft | YYYY-MM-DD | Title | YYYY-MM-DD |
            local ttl_date
            ttl_date=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $5); print $5}')
            if [ -n "${ttl_date}" ]; then
                local ttl_epoch
                ttl_epoch=$(date -j -f "%Y-%m-%d" "${ttl_date}" +%s 2>/dev/null || echo 0)
                local now_epoch
                now_epoch=$(date +%s)
                if [ "${ttl_epoch}" -gt 0 ] && [ "${now_epoch}" -gt "${ttl_epoch}" ]; then
                    local title
                    title=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4); print $4}')
                    echo "   🔴 ПРОСРОЧЕНО: ${title} (TTL: ${ttl_date})"
                    ((violations++)) || true
                fi
            fi
        done < <(grep "^| draft " "${DRAFT_LIST}" 2>/dev/null || true)
        if [ "${violations}" -eq 0 ]; then
            echo "   ✅ Все черновики в TTL"
        fi
    fi

    # fleeting-notes
    if [ -f "${FLEETING_NOTES}" ]; then
        local n_fleeting
        n_fleeting=$(grep -c "^\- \[" "${FLEETING_NOTES}" 2>/dev/null || echo 0)
        n_fleeting=$(echo "${n_fleeting}" | head -1)
        echo ""
        echo "💡 Fleet-заметок: ${n_fleeting}"
        if [ "${n_fleeting}" -gt 10 ]; then
            echo "   ⚠️  >10 заметок — пора на Note-Review"
        fi
    fi

    # Packs
    local n_packs=0
    if [ -d "${PACKS_DIR}" ]; then
        n_packs=$(find "${PACKS_DIR}" -maxdepth 2 -name "index.md" -type f 2>/dev/null | wc -l | tr -d '[:space:]')
    fi
    echo ""
    echo "📦 Pack-ов (локальных): ${n_packs}"

    # Published
    local n_published=0
    if [ -d "${PUBLISHED_DIR}" ]; then
        n_published=$(find "${PUBLISHED_DIR}" -name "*.md" -type f 2>/dev/null | wc -l | tr -d '[:space:]')
    fi
    echo "📢 Опубликовано: ${n_published}"

    # Health test (PD.FORM.005: 4 вопроса)
    echo ""
    echo "═══════════════════════════════════════════"
    echo "  ТЕСТ ЗДОРОВЬЯ КОНВЕЙЕРА"
    echo "═══════════════════════════════════════════"
    echo ""
    # 1. In ≈ Out?
    echo "1️⃣  Входящие ≈ исходящие?"
    echo "   Captures: ${n_captures} | Drafts: ${n_drafts} | Published: ${n_published}"
    if [ "${n_captures}" -le $((n_drafts + n_published + 5)) ]; then
        echo "   ✅ Баланс в норме"
    else
        echo "   ❌ Накапливается: captures (${n_captures}) >> draft+published ($((n_drafts + n_published)))"
    fi

    # 2. TTL
    echo ""
    echo "2️⃣  TTL не нарушены?"
    # (already checked above)

    # 3. Guard
    echo ""
    echo "3️⃣  Guard не нарушен?"
    if [ "${n_drafts}" -le 5 ]; then
        echo "   ✅ Да"
    else
        echo "   ❌ Нет (${n_drafts} черновиков)"
    fi

    # 4. Pack → post?
    echo ""
    echo "4️⃣  Pack → пост?"
    if [ "${n_packs}" -gt 0 ] && [ "${n_published}" -eq 0 ]; then
        echo "   ❌ Pack есть, постов нет"
    elif [ "${n_packs}" -gt 0 ]; then
        echo "   ✅ Публикации есть"
    else
        echo "   — Pack-ов ещё нет"
    fi

    # Overall
    echo ""
    local health=0
    [ "${n_captures}" -le $((n_drafts + n_published + 5)) ] || ((health++)) || true
    [ "${n_drafts}" -le 5 ] || ((health++)) || true
    [ "${stale_captures:-0}" -eq 0 ] || ((health++)) || true
    [ "${violations:-0}" -eq 0 ] || ((health++)) || true

    if [ "${health}" -eq 0 ]; then
        echo "═══════════════════════════════════════════"
        echo "  ИТОГ: ✅ Конвейер здоров (${health}/4 проблем)"
        echo "═══════════════════════════════════════════"
    else
        echo "═══════════════════════════════════════════"
        echo "  ИТОГ: ⚠️  Конвейер застопорился (${health}/4 проблем)"
        echo "  → Тема для стратегической сессии"
        echo "═══════════════════════════════════════════"
    fi
}

# --- promote-to-pack ---
promote_to_pack() {
    local capture_file="$1"
    local domain="${2:-general}"

    if [ ! -f "${capture_file}" ]; then
        echo "❌ Файл не найден: ${capture_file}"
        exit 1
    fi

    local filename
    filename=$(basename "${capture_file}")
    local domain_dir="${PACKS_DIR}/${domain}"
    local target="${domain_dir}/${filename}"

    mkdir -p "${domain_dir}"

    # Create Pack index if first entity
    if [ ! -f "${domain_dir}/index.md" ]; then
        cat > "${domain_dir}/index.md" << EOF
# Pack: ${domain}

**Создан:** $(date +%Y-%m-%d)
**Статус:** active
**Тип:** локальный Pack (пре-GitHub)
**Источник:** PD.FORM.005 Creative Pipeline

## Сущности
EOF
    fi

    # Copy capture to Pack
    cp "${capture_file}" "${target}"
    echo "✅ ${filename} → packs/${domain}/"

    # Register in index
    echo "- $(date +%Y-%m-%d): ${filename}" >> "${domain_dir}/index.md"

    # Optional: remove from captures (or keep as archive)
    echo ""
    echo "   Исходный capture в ${CAPTURE_DIR} сохранён."
    echo "   Для удаления: rm ${capture_file}"
}

# --- promote-draft ---
promote_draft() {
    local draft_file="$1"

    if [ ! -f "${draft_file}" ]; then
        echo "❌ Файл не найден: ${draft_file}"
        exit 1
    fi

    local filename
    filename=$(basename "${draft_file}")
    local target="${PUBLISHED_DIR}/${filename}"

    mkdir -p "${PUBLISHED_DIR}"

    cp "${draft_file}" "${target}"

    # Update draft-list: draft → published
    local title
    title=$(head -1 "${draft_file}" | sed 's/^# //')
    if [ -f "${DRAFT_LIST}" ] && [ -n "${title}" ]; then
        # Update status from draft to published
        perl -i -CS -pe "s/\\| draft \\|.*\\| ${title} \\|.*\\|/| published |$(date +%Y-%m-%d)| ${title} | — |/" "${DRAFT_LIST}" 2>/dev/null || true
    fi

    echo "✅ ${filename} → published/"
    echo "   Статус в draft-list обновлён: draft → published"
}

# --- resolve-captures ---
resolve_captures() {
    echo "═══════════════════════════════════════════"
    echo "  РАЗБОР CAPTURES (7 направлений)"
    echo "═══════════════════════════════════════════"
    echo ""

    local count=0
    for f in "${CAPTURE_DIR}"/*.md; do
        [ -f "$f" ] || continue
        ((count++)) || true

        local title
        title=$(head -1 "$f" | sed 's/^## //' | sed 's/^# //')
        local age
        age=$(days_old "$f")

        echo "${count}. [${age}д] ${title}"
        echo "   Файл: $(basename "$f")"
        echo ""
        echo "   Куда направить?"
        echo "   1. НЭП (dissatisfaction)  2. Задача (task)"
        echo "   3. Знание → Pack (capture)  4. Черновик → пост (draft)"
        echo "   5. Идея (idea)  6. Личное (personal)"
        echo "   7. Шум (noise)  s. Пропустить"
        echo "   ---"
        echo "   Команда: capture.sh --type <тип> \"${title}\" \"разбор captures\""
        echo ""
    done

    if [ "${count}" -eq 0 ]; then
        echo "✅ Нет captures для разбора"
    else
        echo "═══════════════════════════════════════════"
        echo "Всего: ${count} capture(ов) ждут разбора"
        echo "Для каждого — выбери направление и вызови capture.sh --type <тип>"
        echo "═══════════════════════════════════════════"
    fi
}

# --- Dispatch ---
case "${CMD}" in
    check)
        check
        ;;
    promote-to-pack)
        [ -z "${2:-}" ] && { echo "❌ Укажи capture-файл"; usage; }
        promote_to_pack "$2" "${3:-general}"
        ;;
    promote-draft)
        [ -z "${2:-}" ] && { echo "❌ Укажи draft-файл"; usage; }
        promote_draft "$2"
        ;;
    resolve-captures)
        resolve_captures
        ;;
    *)
        usage
        ;;
esac
