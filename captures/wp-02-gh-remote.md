# WP-2: GitHub remote + update.sh check

**Дата:** 2026-06-01
**W23** (1–7 июня 2026)

## Выполнено

1. **Git remote `origin` добавлен** для 3 репозиториев:
   - `~/iwe-platform/` → `https://github.com/artymorales/iwe-platform.git`
   - `~/ds-strategy/` → `https://github.com/artymorales/ds-strategy.git`
   - `~/ds-knowledge-index/` → `https://github.com/artymorales/ds-knowledge-index.git`

2. **`update.sh` проверен** — найден в `~/iwe-platform/scripts/update.sh` (21 KB, executable).
   - FMT-синхронизатор: клонирует `TserenTserenov/FMT-exocortex-template`, применяет white/blue файлы, сохраняет AUTHOR-ONLY зоны.
   - Поддерживает `--check`, `--dry-run`, `--force`, `--version=vX.Y.Z`, `--manifest-update`.
   - Логика корректная (semver sort, sha256 idempotency, preserve author-only zones).

## Осталось

- Пуш на GitHub (после первого коммита/настройки auth).
