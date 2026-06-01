// IWE — Intellectual Work Environment
// Aethon Extension: боковая панель для ORЗ-протоколов
// Устанавливается в ~/iwe-platform/.aethon/extensions/iwe.ts

export function register(api: any) {
  const IWE_DIR = "~/iwe-platform";
  const STRATEGY_DIR = "~/ds-strategy";
  const KNOWLEDGE_DIR = "~/ds-knowledge-index";

  // --- Sidebar секция ---
  api.registerSidebarSection({
    id: "iwe",
    title: "IWE",
    items: [
      { id: "day-open", label: "☀️ Открыть день" },
      { id: "day-close", label: "🌙 Закрыть день" },
      { id: "week-close", label: "📅 Закрыть неделю" },
      { id: "session-status", label: "📋 Статус сессии" },
      { id: "capture", label: "📝 Захват знания" },
    ],
  });

  // --- Обработчики ---

  // ☀️ Day Open
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "day-open" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        `Выполни ритуал **Открытие дня**:

1. Запусти \`bash ${IWE_DIR}/scripts/day-open.sh\`
2. Покажи краткий итог: день, WeekPlan (есть/нет), dirty-репозитории
3. Спроси, чем будем заниматься сегодня`
      );
    }
  );

  // 🌙 Day Close
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "day-close" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        `Выполни ритуал **Закрытие дня**:

1. Запусти \`bash ${IWE_DIR}/scripts/day-close.sh\`
2. Capture-to-Pack: спроси, появилось ли знание, которое стоит сохранить
   - Правило (1-3 строки) → ${IWE_DIR}/memory/distinctions.md
   - Протокол → ${IWE_DIR}/memory/protocols/
   - Доменное знание → ${KNOWLEDGE_DIR}/captures/
   - Рефлексия → ${KNOWLEDGE_DIR}/drafts/
3. Спроси, всё ли сделано на сегодня`
      );
    }
  );

  // 📅 Week Close
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "week-close" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        `Выполни ритуал **Закрытие недели**:

1. Запусти \`bash ${IWE_DIR}/scripts/week-close.sh\`
2. Предложи провести стратегическую сессию:
   - Разобрать inbox в ${STRATEGY_DIR}/inbox/
   - Обновить WP-REGISTRY в ${STRATEGY_DIR}/docs/
   - Проверить цели на следующую неделю
3. Capture-to-Pack по накопленным за неделю знаниям`
      );
    }
  );

  // 📋 Session Status
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "session-status" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        `Сделай **дашборд текущей сессии**:

1. Проверь: был ли сегодня day-open (есть ли файл \`${STRATEGY_DIR}/current/day-$(date +%Y-%m-%d).md\`)
2. Проверь dirty-репозитории: \`git status --short\` в ${IWE_DIR}, ${STRATEGY_DIR}, ${KNOWLEDGE_DIR}
3. Проверь WeekPlan на текущую неделю в ${STRATEGY_DIR}/current/
4. Покажи краткий дашборд:
   - ✅/❌ Day Open сегодня
   - 📋 WeekPlan (есть/нет)
   - 🔄 Dirty файлы по репозиториям
   - 💡 Предложение по следующему действию`
      );
    }
  );

  // 📝 Capture
  api.onEvent(
    { componentType: "sidebar-item", descendantId: "capture" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        `Помоги зафиксировать знание (Capture-to-Pack).

Спроси у пользователя:
1. Что узнал?
2. Откуда (контекст)?
3. Куда сохранить?
   - **Правило** (1-3 строки) → ${IWE_DIR}/memory/distinctions.md
   - **Протокол/процесс** → ${IWE_DIR}/memory/protocols/
   - **Доменное знание** → ${KNOWLEDGE_DIR}/captures/
   - **Урок/рефлексия** → ${KNOWLEDGE_DIR}/drafts/

Формат capture:
\`\`\`markdown
## YYYY-MM-DD: Тема

Что узнал: ...
Откуда: ...
Контекст: ...
\`\`\``
      );
    }
  );
}
