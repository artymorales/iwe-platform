# Протокол хуков-ограждений IWE (Pre-action Gates)

> **WP-34:** Сверка с FMT/PACK + проектирование архитектуры для Pi agent + Aethon.
> **Создан:** 2026-06-29
> **Источники:** DP.M.008 §8 (PACK), FMT protocol-work.md §3, DP.ARCH.008 (Enforcement vs Memory)
> **Адаптация:** Pi agent + Aethon (нет `.claude/hooks/`, агент сам выполняет проверки)

---

## 0. Архитектурный фундамент

**Принцип DP.ARCH.008:** Наблюдатель должен быть ВНЕ субъекта. Шкала сил:

| Класс | Сила | Реализация | Пример |
|-------|------|------------|--------|
| **M (memory)** | 0 | Правило в AGENTS.md / memory | «Не забудь проверить» |
| **F (hook)** | Средняя | Скрипт + детектор + лог | `verif-gate.sh` → gate_log |
| **L (deterministic)** | Максимальная | Генерация артефакта до действия | `day-open.sh` генерирует DayPlan |

**Правило выбора класса:**
- Gate требует человеческого суждения → **M** (агент сверяется с memory)
- Gate проверяем алгоритмически → **F** (скрипт-хук)
- Gate можно устранить, изменив процесс → **L** (детерминированная генерация)

**Адаптация под Pi agent:** В Claude Code enforcement идёт через `.claude/hooks/` (события: PreToolUse, PostToolUse, Stop). В Pi agent нет системы хуков. Все проверки — **встроены в AGENTS.md и протоколы**, агент выполняет их сам. Класс F реализуется через bash-скрипты, вызываемые агентом до/после действия.

---

## 1. Восемь гейтов IWE

| # | Gate | Класс (сейчас) | Класс (цель) | Источник FMT/PACK | Статус |
|---|------|---------------|-------------|-------------------|--------|
| **G1** | Rhythm Gate | M | F | Правило 0 AGENTS.md | ✅ memory |
| **G2** | WP Gate (Verif Gate) | F | F | DP.M.008 §8.1, Правило 1 AGENTS.md | ✅ `verif-gate.sh` |
| **G3** | Day Gate | M | F | Pre-action AGENTS.md §4 | ⚠️ memory (day-open.sh L) |
| **G4** | Pull Gate | M | M | Правило 3 AGENTS.md | ✅ memory |
| **G5** | Commit Gate | M | F | DP.M.008 §8.2, FMT §3 | ⚠️ memory |
| **G6** | Arch Gate | F | F | DP.M.008 §8.3, DP.M.005 | ✅ `archgate.sh` |
| **G7** | Close Gate | M | F | Правило 2 AGENTS.md, FMT §3 (Capture-back) | ⚠️ memory |
| **G8** | Integration Gate | — | M | DP.M.008 §8.5 | ❌ отсутствует |

---

## 2. Описание каждого гейта

### G1. Rhythm Gate

**Инвариант:** Система живёт в еженедельном ритме. Пн = strategy_day → Strategy Session. Вс/Пн утро = Week Close. Первый Пн месяца = Month Close.

**Момент срабатывания:** Начало сессии, Day Open.

**Проверка:**
- Какой сегодня день недели?
- Если strategy_day → предложить Strategy Session (после Week Close)
- Если первый Пн месяца → Month Close перед Strategy Session

**Реализация сейчас:** Правило 0 в AGENTS.md (M).
**Целевая:** F — скрипт `rhythm-gate.sh`, вызываемый при Day Open.

### G2. WP Gate (Verif Gate)

**Инвариант:** Любое новое задание вне текущего WeekPlan требует классификации и согласования.

**Момент срабатывания:** Пользователь даёт новое задание.

**Проверка:**
1. Задание в текущем DayPlan/WeekPlan? → работаем
2. Нет → Verif Gate: класс задачи (trivial/closed-loop/open-loop/problem-framing)
3. Объявить роль, РП, бюджет, класс, модель
4. Дождаться «да»/«делаем»/«открывай»

**Реализация сейчас:** `verif-gate.sh` (F) + Правило 1 в AGENTS.md.
**Статус:** ✅ done.

### G3. Day Gate

**Инвариант:** Не начинать работу без Day Open. Day Open создаёт DayPlan на сегодня.

**Момент срабатывания:** Первая сессия дня.

**Проверка:**
1. Существует ли DayPlan на сегодня? Если да → Day Open был
2. Нет → предложить Day Open (`day-open.sh`)

**Связанный детерминизм (L):** `day-open.sh` генерирует DayPlan из шаблона + carry-over из Day Close + WeekPlan.

**Реализация сейчас:** Pre-action Gate в AGENTS.md §4 (M) + `day-open.sh` (L для генерации DayPlan).
**Целевая:** F — gate-check внутри `day-open.sh` или отдельный `day-gate.sh`.

### G4. Pull Gate (Pull-on-Touch)

**Инвариант:** При первом обращении к репозиторию за сессию — `git pull --rebase`.

**Момент срабатывания:** Первая операция (ls, read, find, edit, commit) в репозитории.

**Проверка:**
1. `git status` — dirty? → stash или пропустить с пометкой
2. `git pull --rebase` → конфликт? → стоп, отчёт пользователю
3. Нет сети → работать с локальной копией, пометка «potentially stale»

**Реализация сейчас:** Правило 3 в AGENTS.md (M).
**Целевая:** M (требует человеческого суждения: stash? skip? конфликт?).

### G5. Commit Gate

**Инвариант:** Перед git commit в репозитории с AGENTS.md — прочитать его.

**Момент срабатывания:** Перед `git add -A && git commit`.

**Проверка:**
1. В репозитории есть AGENTS.md / CLAUDE.md? → прочитать (проверить, не нарушено ли правило)
2. Нет → обычный commit

**Связанный Capture-back (FMT §3):** После изменения системы → `grep` на упоминания изменённой системы в memory/ → обновить устаревшие записи.

**Реализация сейчас:** Неявно через Правило 2 (Close) — «сначала commit + push».
**Целевая:** F — `commit-gate.sh`: проверяет наличие AGENTS.md, напоминает прочитать.

### G6. Arch Gate

**Инвариант:** Архитектурное решение → оценка по 7 характеристикам ЭМОГССБ. Порог ≥8 (из 10×7=70: ≥56). Без прохождения — решение не принимается.

**Момент срабатывания:** Перед принятием архитектурного решения.

**Проверка:** `archgate.sh` — скрипт вызывает сам себя через `startTask` с pro-моделью.

**Реализация сейчас:** `archgate.sh` (F) + AGENTS.md Правило 7.
**Статус:** ✅ done.

### G7. Close Gate

**Инвариант:** При любом закрытии (сессия/день/неделя) — сначала commit + push по ВСЕМ затронутым репозиториям, потом отчёт и capture.

**Момент срабатывания:** Сессия Close, Day Close, Week Close.

**Проверка:**
1. `git status --short` по iwe-platform, ds-strategy, ds-knowledge-index
2. Незакоммиченные изменения → `git add -A && git commit` → push
3. Capture-to-Pack (Правило 4)
4. Только потом — отчёт, итоги

**Связанный Capture-back:** После commit — `grep memory/` на упоминания изменённой системы.

**Реализация сейчас:** Правило 2 в AGENTS.md (M) + `day-close.sh` + `week-close.sh`.
**Целевая:** F — `close-gate.sh`: проверяет git status во всех трёх репозиториях, флаг `--no-commit` для ручного режима.

### G8. Integration Gate

**Инвариант:** Новый инструмент/агент/система → определить: тип, контур (inner/outer), роли, продукты, процессы.

**Момент срабатывания:** Перед добавлением нового инструмента в IWE.

**Проверка:**
1. Что это? (тип: скрипт, MCP-сервер, расширение Aethon, внешний сервис)
2. В какой контур попадает? (inner = часть IWE, outer = внешний)
3. Какие роли затронуты?
4. Какие рабочие продукты создаёт/меняет?
5. Какие процессы затрагивает? (нужно обновить service-catalog, MAP?)

**Реализация сейчас:** Отсутствует ❌.
**Целевая:** M/F — `integration-gate.sh`: чек-лист из 5 вопросов, запись в `gate_log.jsonl`.

---

## 3. Матрица покрытия FMT/PACK

| Gate FMT/PACK | IWE Gate | Совпадение | Различия |
|---------------|----------|-----------|----------|
| WP Gate (DP.M.008) | G2 WP Gate | ✅ Полное | — |
| Git commit → CLAUDE.md (DP.M.008) | G5 Commit Gate | ⚠️ Частичное | FMT: read CLAUDE.md. IWE: read AGENTS.md + capture-back |
| АрхГейт (DP.M.008) | G6 Arch Gate | ✅ Полное | — |
| Priority Gate РП≥3h (DP.M.008) | — (в G2 WP Gate) | ⚠️ Неявно | Отдельный гейт не выделен, проверяется в WP Gate |
| IntegrationGate (DP.M.008) | G8 Integration Gate | ❌ Отсутствует | Требует создания |
| Сервисы MAP.002 (FMT §3) | — (в G2 WP Gate) | ⚠️ Неявно | Агент сверяется с service-catalog.md |
| Capture-back (FMT §3) | — (в G7 Close Gate) | ⚠️ Частично | Делается при Close, не перед каждым commit |
| Day Open gate (AGENTS.md) | G3 Day Gate | ✅ IWE-специфичный | Нет в FMT (там другой механизм) |
| Pull-on-Touch (AGENTS.md) | G4 Pull Gate | ✅ IWE-специфичный | Нет в FMT |
| Close gate (AGENTS.md) | G7 Close Gate | ✅ IWE-специфичный | Расширен относительно FMT (3 репо + capture) |
| Rhythm Gate (AGENTS.md) | G1 Rhythm Gate | ✅ IWE-специфичный | — |

---

## 4. План реализации (от текущего к целевому)

### Фаза 1: Gaps закрыть (сейчас)

| # | Gate | Действие |
|---|------|----------|
| **G8** | Integration Gate | Создать `scripts/skills/integration-gate.sh` — чек-лист из 5 вопросов |
| **G5** | Commit Gate | Формализовать в AGENTS.md: перед commit → read AGENTS.md + capture-back |
| **G3** | Day Gate | Перенести проверку в `day-open.sh` (F): если DayPlan уже есть → skip |
| **G7** | Close Gate | Добавить `close-gate.sh` — проверка git status по 3 репо |

### Фаза 2: Поднять класс (F)

| # | Gate | Текущий | Целевой | Действие |
|---|------|---------|---------|----------|
| **G1** | Rhythm Gate | M | F | `rhythm-gate.sh` — проверка дня недели, вызов при day-open |
| **G3** | Day Gate | M | F | Встроить в `day-open.sh` |
| **G7** | Close Gate | M | F | `close-gate.sh` |
| **G5** | Commit Gate | M | F | `commit-gate.sh` |

### Фаза 3: Логирование (F→F+)

Добавить `gate_log.jsonl` для всех F-гейтов:
```jsonl
{"ts":"2026-06-29T10:15:00+03:00","gate":"G2","decision":"pass","class":"closed-loop"}
{"ts":"2026-06-29T14:30:00+03:00","gate":"G7","decision":"pass","repos":["iwe-platform","ds-strategy"]}
```

**Место:** `~/ds-strategy/logs/gate_log.jsonl`

---

## 5. Интеграция в AGENTS.md

Текущая секция §4 «Pre-action Gates» должна быть обновлена до 8 gates:

```markdown
## 4. Pre-action Gates (8 хуков-ограждений)

| Момент | Gate | Проверка |
|--------|------|----------|
| Начало сессии | **G3 Day Gate** | Был ли Day Open сегодня? |
| Начало сессии | **G1 Rhythm Gate** | Strategy day? Month Close? |
| Новое задание | **G2 WP Gate** | verif-gate.sh → класс → согласование |
| Первое обращение к репо | **G4 Pull Gate** | git pull --rebase |
| Перед commit | **G5 Commit Gate** | Прочитать AGENTS.md репо + capture-back |
| Архитектурное решение | **G6 Arch Gate** | archgate.sh → ЭМОГССБ ≥56 |
| Перед закрытием | **G7 Close Gate** | commit+push по 3 репо + capture |
| Новый инструмент | **G8 Integration Gate** | integration-gate.sh → 5 вопросов |
```

---

## 6. Антипаттерны (из DP.ARCH.008)

| # | Антипаттерн | Защита |
|---|------------|--------|
| A1 | Memory-only enforcement | Каждый gate должен иметь дорожку к F (скрипт) или L (генерация) |
| A2 | Наблюдатель внутри субъекта | Хуки используют `IWE_ROOT` env var, не relative path |
| A3 | Hook без диагностического лога | Все F-гейты пишут в `gate_log.jsonl` |
| A4 | Усиление memory вместо повышения класса | Если правило нарушено ≥3 раз → поднять класс (M→F→L) |

---

*Создано: 2026-06-29 · WP-34 · Сверка: DP.M.008, FMT protocol-work.md, DP.ARCH.008*
