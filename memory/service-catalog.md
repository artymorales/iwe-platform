# Каталог сервисов IWE (адаптированный)

> **Источник:** DP.MAP.002 (FMT) → упрощённая версия для Pi agent + Aethon.
> **Назначение:** перед началом работы агент определяет, какие сервисы затронуты.
> **Обновлять:** при добавлении нового протокола, скрипта или подсистемы.

---

## Сервисы

| ID | Сервис | Где описан | Зачем |
|----|--------|-----------|-------|
| **S01** | Day Plan | `protocols/open.md §Day Open`, `scripts/day-open.sh` | План дня, открытие дня |
| **S02** | Week Plan | `protocols/close.md §Week Close`, `scripts/week-close.sh` | План недели, закрытие недели |
| **S03** | Session (ОРЗ) | `protocols/open.md`, `protocols/work.md`, `protocols/close.md` | Цикл Открытие→Работа→Закрытие |
| **S04** | Capture | `protocols/work.md §2`, `memory/distinctions.md` | Захват знаний: различения, captures, drafts |
| **S05** | WP Registry | `protocols/open.md §WP Gate`, `~/ds-strategy/docs/WP-REGISTRY.md` | Реестр Work Packages, WP Gate |
| **S06** | Strategy | `protocols/strategy-session.md`, `week-close.sh` | Стратегическая сессия, Month Close |
| **S07** | Verification | `protocols/work.md §7`, `scripts/skills/archgate.sh` | Верификация артефактов, ArchGate |
| **S08** | Git Workflow | `protocols/open.md §Pull-on-Touch`, `protocols/close.md §1` | Pull-on-Touch, commit+push |
| **S09** | Handoff | `protocols/work.md §2a`, `protocols/close.md §3` | Контекстные файлы РП, передача между сессиями |
| **S10** | Day Rhythm | `memory/day-rhythm-config.yaml` | Конфигурация ритма дня, strategy_day |
| **S11** | Decision Capture | `protocols/work.md §3` | Фиксация architectural/strategic решений |

## Файлы конфигурации (не сервисы, но затрагиваются)

| Файл | Что содержит |
|------|-------------|
| `AGENTS.md` | Правила верхнего уровня |
| `params.yaml` | Конфигурация (пути, модели, настройки) |
| `memory/distinctions.md` | Ключевые различения |
| `memory/verification-classes.md` | Классы верификации |
| `memory/t-checklist.md` | Чеклисты Close |
