// IWE — Intellectual Work Environment
// Aethon Extension: ритм дня + действия
// Устанавливается в ~/iwe-platform/.aethon/extensions/iwe.ts

export function register(api: any) {
  const IWE_DIR = "~/iwe-platform";
  const STRATEGY_DIR = "~/ds-strategy";
  const KNOWLEDGE_DIR = "~/ds-knowledge-index";

  // ================================================================
  // 1. Состояние — трекинг выполнения
  // ================================================================

  function today() {
    const d = new Date();
    return d.toISOString().slice(0, 10);
  }

  function statePath(itemId: string): string {
    return `/iwe/rhythm/${today()}/${itemId}`;
  }

  function todayItemLabel(itemId: string, label: string): string {
    return label;
  }

  // ================================================================
  // 2. Секция "Ритм дня" — чеклист ручных действий
  // ================================================================

  api.registerSidebarSection({
    id: "rhythm",
    title: "📋 Ритм дня",
    items: [
      { id: "rh-day-open",     label: "☀️ Открыть день" },
      { id: "rh-self-dev",     label: "📚 Саморазвитие (слот 1)" },
      { id: "rh-work-session", label: "⚡ Рабочая сессия" },
      { id: "rh-day-close",    label: "🌙 Закрыть день" },
      { id: "rh-week-close",   label: "📅 Закрытие недели" },
      { id: "rh-strategy",     label: "🎯 Стратегическая сессия" },
      { id: "rh-capture",      label: "📝 Захват знания" },
    ],
  });

  // --- Day Open ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "rh-day-open" },
    async (_e: any, ctx: any) => {
      const done = await ctx.pi.session.model; // just to have ctx

      const path = statePath("day-open");
      ctx.setState(path, "pending");
      await ctx.pi.prompt(
        `Выполни **Открытие дня**:

1. Запусти \`bash ${IWE_DIR}/scripts/day-open.sh\`
2. Покажи краткий итог: день недели, есть ли WeekPlan, dirty-репозитории
3. Спроси, чем будем заниматься сегодня

После выполнения — скажи "готово".`
      );
      ctx.setState(path, "done");
    }
  );

  // --- Self-Development ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "rh-self-dev" },
    async (_e: any, ctx: any) => {
      const path = statePath("self-dev");
      ctx.setState(path, "pending");
      await ctx.pi.prompt(
        `Напомни пользователю про **слот саморазвития** (первый слот дня).

Вопрос: "Что сегодня изучаем? Книга, курс, статья — 30-60 мин."
После завершения — спроси, записать capture.`
      );
      ctx.setState(path, "done");
    }
  );

  // --- Work Session ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "rh-work-session" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        `Помоги начать **рабочую сессию** по протоколу:

1. **Verif Gate** — определи класс задачи (trivial/closed-loop/open-loop/problem-framing)
2. **WP Gate** — проверь, есть ли задача в WeekPlan. Если нет — согласуй
3. **Ритуал** — объяви: роль пользователя · роль агента · работа · РП · класс · метод · оценка
4. Дождись явного "да" и работай

Формат объявления:
> **Роль пользователя:** [разработчик / пользователь / ...]
> **Роль агента:** [стратег / экстрактор / кодер / ...]
> **Работа:** [что делаем]
> **РП:** [WP-N, если есть]
> **Класс верификации:** [trivial / closed-loop / open-loop / problem-framing]
> **Метод:** [как]
> **Оценка:** ~Xh`
      );
    }
  );

  // --- Day Close ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "rh-day-close" },
    async (_e: any, ctx: any) => {
      const path = statePath("day-close");
      ctx.setState(path, "pending");
      await ctx.pi.prompt(
        `Выполни **Закрытие дня**:

1. Запусти \`bash ${IWE_DIR}/scripts/day-close.sh\`
2. Capture-to-Pack: спроси, появилось ли знание
3. Заполни секцию "Итог дня" в DayPlan:
   - Сделано / Не сделано
   - Captures
   - **Задел на завтра** (с чего начать следующим утром)

После выполнения — скажи "готово".`
      );
      ctx.setState(path, "done");
    }
  );

  // --- Week Close ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "rh-week-close" },
    async (_e: any, ctx: any) => {
      const path = statePath("week-close");
      ctx.setState(path, "pending");
      await ctx.pi.prompt(
        `Выполни **Закрытие недели**:

1. Запусти \`bash ${IWE_DIR}/scripts/week-close.sh\`
2. Обнови WP-REGISTRY (${STRATEGY_DIR}/docs/WP-REGISTRY.md) — статусы РП
3. Запусти активный sweep: \`bash ${IWE_DIR}/scripts/active-wp-sweep.sh\`
4. Предложи провести стратегическую сессию (понедельник)

После выполнения — скажи "готово".`
      );
      ctx.setState(path, "done");
    }
  );

  // --- Strategy Session ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "rh-strategy" },
    async (_e: any, ctx: any) => {
      const path = statePath("strategy");
      ctx.setState(path, "pending");
      await ctx.pi.prompt(
        `Запусти **Стратегическую сессию** по протоколу:

1. Контекст: прочитай протокол ${IWE_DIR}/memory/protocols/strategy-session.md
2. Запусти активный sweep: \`bash ${IWE_DIR}/scripts/active-wp-sweep.sh\`
3. Пройди шаги протокола (Weekly flow):
   - Ревью НЭП
   - Анализ прошлой недели
   - Разбор inbox
   - Стратегическая сверка
   - Формирование WeekPlan (с Verif Gate для каждого РП)
   - DayPlan на сегодня

Модель: pro (тяжёлая). Длительность: ~1-2ч.`
      );
      ctx.setState(path, "done");
    }
  );

  // --- Capture ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "rh-capture" },
    async (_e: any, ctx: any) => {
      try {
        ctx.pi.notify("📝 Захват знания...");
      } catch (_) {}
      await ctx.pi.prompt(
        `Помоги зафиксировать знание (Capture-to-Pack).

Спроси у пользователя:
1. **Что узнал?** (паттерн, различение, метод, инсайт)
2. **Откуда?** (контекст)
3. **Куда сохранить?**
   - **Правило** (1-3 строки) → ${IWE_DIR}/memory/distinctions.md
   - **Протокол/процесс** → ${IWE_DIR}/memory/protocols/
   - **Доменное знание** → ${KNOWLEDGE_DIR}/captures/
   - **Урок/рефлексия** → ${KNOWLEDGE_DIR}/drafts/

Формат:
\`\`\`markdown
## YYYY-MM-DD: Тема

Что узнал: ...
Откуда: ...
Контекст: ...
\`\`\`

Анонсируй действие: «Capture: [что] → [куда]»`
      );
    }
  );

  // ================================================================
  // 3. Секция "Инструменты" — быстрые bash-действия
  // ================================================================

  api.registerSidebarSection({
    id: "tools",
    title: "🛠 Инструменты",
    items: [
      { id: "tool-sweep",        label: "📊 Sweep активных РП" },
      { id: "tool-status",       label: "🔍 Статус репозиториев" },
      { id: "tool-fmt-update",   label: "🔄 Проверить FMT" },
      { id: "tool-reset-day",    label: "🔄 Сбросить статус дня" },
    ],
  });

  // --- Sweep ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "tool-sweep" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        `Запусти активный sweep: \`bash ${IWE_DIR}/scripts/active-wp-sweep.sh\``
      );
    }
  );

  // --- Status ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "tool-status" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        `Сделай **дашборд состояния**:

1. Была ли сегодня стратегическая сессия? (проверь WeekPlan)
2. Был ли Day Open сегодня? (есть ли \`${STRATEGY_DIR}/current/dayplan-*.md\`)
3. Dirty-репозитории: \`git status --short\` в ${IWE_DIR}, ${STRATEGY_DIR}, ${KNOWLEDGE_DIR}
4. WeekPlan: есть ли в ${STRATEGY_DIR}/current/

Покажи компактный дашборд (эмодзи + 1 строка каждый)`
      );
    }
  );

  // --- FMT check ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "tool-fmt-update" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        `Проверь, есть ли новая версия FMT-шаблона:

\`\`\`bash
bash ${IWE_DIR}/scripts/fmt-version-check.sh
\`\`\`

Если есть — покажи детали и спроси, обновлять ли.`
      );
    }
  );

  // --- Reset day state ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "tool-reset-day" },
    async (_e: any, ctx: any) => {
      // Reset today's rhythm state to "todo"
      const items = [
        "day-open", "self-dev", "day-close", "week-close", "strategy"
      ];
      try {
        for (const item of items) {
          ctx.setState(`/iwe/rhythm/${today()}/${item}`, "todo");
        }
        ctx.pi.notify("🔄 Статус ритма сброшен");
        await ctx.pi.prompt(
          `Статус ритма на сегодня сброшен. Начинаем день заново. С чего начнём?`
        );
      } catch (e) {
        ctx.pi.notify("⚠️ Ошибка: " + (e?.message || e));
      }
    }
  );
}
