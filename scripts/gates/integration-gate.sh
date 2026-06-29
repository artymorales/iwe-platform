#!/usr/bin/env bash
# integration-gate.sh — G8: Integration Gate
# Проверка перед добавлением нового инструмента/агента/системы в IWE.
# Использование: bash ~/iwe-platform/scripts/gates/integration-gate.sh
# Источник: DP.M.008 §8.5 (PACK), WP-34
set -euo pipefail

echo "=== G8 Integration Gate: новый инструмент ==="
echo ""

echo "Перед добавлением нового инструмента в IWE — ответь на 5 вопросов:"
echo ""
echo "1. ТИП: Что это?"
echo "   [ ] Скрипт (bash/shell)"
echo "   [ ] MCP-сервер"
echo "   [ ] Расширение Aethon (.ts)"
echo "   [ ] Внешний сервис (API, SaaS)"
echo "   [ ] Инструмент Pi agent"
echo "   [ ] Другое: ___"
echo ""
echo "2. КОНТУР: Где будет жить?"
echo "   [ ] Inner (часть IWE — ~/iwe-platform/)"
echo "   [ ] Outer (внешний — отдельный репозиторий/сервис)"
echo "   [ ] Boundary (на границе — MCP-шлюз)"
echo ""
echo "3. РОЛИ: Кто будет использовать?"
echo "   [ ] Только пользователь (человек)"
echo "   [ ] Только агент (Pi agent)"
echo "   [ ] Оба"
echo ""
echo "4. ПРОДУКТЫ: Какие артефакты создаёт/меняет?"
echo "   [ ] Документация (memory/, docs/)"
echo "   [ ] Код (scripts/, src/)"
echo "   [ ] Конфигурация (params.yaml, .mcp.json)"
echo "   [ ] Данные (DS, captures)"
echo "   [ ] Ничего (только read-only)"
echo ""
echo "5. ПРОЦЕССЫ: Какие протоколы/сервисы затронуты?"
echo "   Сервисы IWE (S01–S12): memory/service-catalog.md"
echo "   Нужно обновить: [ ] service-catalog.md  [ ] AGENTS.md  [ ] params.yaml"
echo ""
echo "---"
echo "Запиши решение в gate_log:"
echo "  ~/ds-strategy/logs/gate_log.jsonl"
echo ""
echo "Формат записи:"
echo '  {"ts":"...","gate":"G8","decision":"pass|block|review","tool":"name","contour":"inner|outer|boundary","note":"..."}'
