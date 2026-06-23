# Документирование архитектуры Security Gateway

> Workflow — как собирать и поддерживать документацию шлюза безопасности.

## Процесс

1. **Сбор конфигов с серверов** — SSH read-only, все актуальные файлы
2. **Кросс-проверка скриптом** — все IP/порты/SNI/PROXY protocol сверяются
3. **Согласование расхождений** — что расходится → вопрос пользователю
4. **Замена sensitive данных** — пароли/ключи → плейсхолдеры
5. **Сохранение** — `~/ds-knowledge-index/docs/security-gateway/`

## Структура (12 файлов)

```
docs/security-gateway/
├── README.md          — обзорная архитектура
├── components.md      — все компоненты, параметры
├── network.md         — топология, SNI, DNS
├── operations.md      — команды обслуживания
├── environment.md     — ОС, sysctl, /root/awg/
└── configs/
    ├── haproxy.md     — haproxy.cfg (Yandex)
    ├── angie.md       — angie.conf (Yandex)
    ├── telemt.md      — telemt.toml (Veesp)
    ├── xray.md        — config.json (Veesp)
    ├── awg.md         — awg0/awg1/awg2 (оба сервера)
    ├── omniroute.md   — docker-compose.yml (Veesp)
    └── reference.md   — статусная таблица
```

> Создано: 2026-06-23 · WP-28
