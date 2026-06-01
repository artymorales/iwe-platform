// IWE — Intellectual Work Environment
// Aethon Extension: ритм дня + действия

export function register(api: any) {
  const IWE_DIR = "~/iwe-platform";
  const STRATEGY_DIR = "~/ds-strategy";
  const KNOWLEDGE_DIR = "~/ds-knowledge-index";

  // ================================================================
  // Ритм дня
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
      await ctx.pi.prompt(
        "Выполни ритуал **Открытие дня**:\n\n" +
        "1. Запусти `bash " + IWE_DIR + "/scripts/day-open.sh`\n" +
        "2. Покажи краткий итог: день недели, WeekPlan (есть/нет), dirty-репозитории\n" +
        "3. Спроси, чем будем заниматься сегодня"
      );
    }
  );

  // --- Self-Development ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "rh-self-dev" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        "Напомни пользователю про **слот саморазвития** (первый слот дня).\n\n" +
        "Спроси: «Что сегодня изучаем? Книга, курс, статья — 30-60 мин.»\n" +
        "После завершения — спроси, нужно ли записать capture."
      );
    }
  );

  // --- Work Session ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "rh-work-session" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        "Помоги начать **рабочую сессию** по протоколу:\n\n" +
        "1. **Verif Gate** — определи класс задачи (trivial/closed-loop/open-loop/problem-framing)\n" +
        "2. **WP Gate** — проверь, есть ли задача в WeekPlan\n" +
        "3. **Ритуал** — объяви: роль · работа · РП · класс · метод · оценка\n" +
        "4. Дождись «да» и работай"
      );
    }
  );

  // --- Day Close ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "rh-day-close" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        "Выполни **Закрытие дня**:\n\n" +
        "1. Запусти `bash " + IWE_DIR + "/scripts/day-close.sh`\n" +
        "2. Capture-to-Pack: спроси, появилось ли знание\n" +
        "3. Заполни секцию «Итог дня» в DayPlan:\n" +
        "   - Сделано / Не сделано\n" +
        "   - Captures\n" +
        "   - **Задел на завтра** (с чего начать утром)"
      );
    }
  );

  // --- Week Close ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "rh-week-close" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        "Выполни **Закрытие недели**:\n\n" +
        "1. Запусти `bash " + IWE_DIR + "/scripts/week-close.sh`\n" +
        "2. Обнови WP-REGISTRY — статусы РП\n" +
        "3. Запусти активный sweep: `bash " + IWE_DIR + "/scripts/active-wp-sweep.sh`\n" +
        "4. Предложи провести стратегическую сессию (понедельник)"
      );
    }
  );

  // --- Strategy Session ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "rh-strategy" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        "Запусти **Стратегическую сессию** по протоколу:\n\n" +
        "1. Прочитай протокол `" + IWE_DIR + "/memory/protocols/strategy-session.md`\n" +
        "2. Запусти активный sweep: `bash " + IWE_DIR + "/scripts/active-wp-sweep.sh`\n" +
        "3. Пройди все шаги Weekly flow (НЭП → анализ → inbox → сверка → WeekPlan → DayPlan)\n\n" +
        "Модель: pro. Длительность: ~1-2ч."
      );
    }
  );

  // --- Capture ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "rh-capture" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        "Помоги зафиксировать знание (Capture-to-Pack).\n\n" +
        "Спроси: Что узнал? Откуда? Куда сохранить?\n" +
        "- Правило → " + IWE_DIR + "/memory/distinctions.md\n" +
        "- Протокол → " + IWE_DIR + "/memory/protocols/\n" +
        "- Доменное знание → " + KNOWLEDGE_DIR + "/captures/\n" +
        "- Урок → " + KNOWLEDGE_DIR + "/drafts/"
      );
    }
  );

  // ================================================================
  // Инструменты
  // ================================================================

  api.registerSidebarSection({
    id: "tools",
    title: "🛠 Инструменты",
    items: [
      { id: "tool-sweep",        label: "📊 Sweep активных РП" },
      { id: "tool-status",       label: "🔍 Статус репозиториев" },
      { id: "tool-fmt-update",   label: "🔄 Проверить FMT-шаблон" },
    ],
  });

  // --- Sweep ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "tool-sweep" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        "Запусти активный sweep: `bash " + IWE_DIR + "/scripts/active-wp-sweep.sh`"
      );
    }
  );

  // --- Status ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "tool-status" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        "Сделай **дашборд состояния**:\n\n" +
        "1. Day Open сегодня? (проверь `" + STRATEGY_DIR + "/current/dayplan-*.md`)\n" +
        "2. Dirty-репозитории: `git status --short` во всех трёх репо\n" +
        "3. WeekPlan: есть ли в `" + STRATEGY_DIR + "/current/`\n\n" +
        "Покажи компактный дашборд (эмодзи + 1 строка каждый)"
      );
    }
  );

  // --- FMT check ---
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "tool-fmt-update" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        "Проверь, есть ли новая версия FMT-шаблона:\n\n" +
        "```bash\nbash " + IWE_DIR + "/scripts/fmt-version-check.sh\n```\n\n" +
        "Если есть — покажи детали и спроси, обновлять ли."
      );
    }
  );
}
