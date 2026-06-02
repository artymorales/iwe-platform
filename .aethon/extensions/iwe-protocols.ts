// iwe-protocols.ts — Кнопки ритуалов и скиллов IWE
// Вызывает bash-скрипты через ctx.pi.prompt()

export function register(api: any) {
  api.registerSidebarSection({
    id: "iwe-rituals",
    title: "IWE · Ритуалы",
    items: [
      { id: "iwe-day-open", label: "☀️ Day Open" },
      { id: "iwe-day-close", label: "🌙 Day Close" },
    ],
  });

  api.registerSidebarSection({
    id: "iwe-skills",
    title: "IWE · Скиллы",
    items: [
      { id: "iwe-wp-new", label: "📦 WP New" },
      { id: "iwe-wp-sweep", label: "📊 WP Sweep" },
    ],
  });

  // События от sidebar items: componentType="sidebar", eventType="select",
  // в данных: { sectionId, itemId }. descendantId матчится на itemId.
  api.onEvent(
    { componentType: "sidebar", descendantId: "iwe-wp-sweep", eventType: "select" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        "Выполни `bash ~/iwe-platform/scripts/active-wp-sweep.sh` — покажи сводку всех активных РП (REGISTRY + inbox + WeekPlan + коммиты за 7 дней).",
      );
    },
  );

  api.onEvent(
    { componentType: "sidebar", descendantId: "iwe-day-open", eventType: "select" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        "Выполни `bash ~/iwe-platform/scripts/day-open.sh` — открой день по протоколу ОРЗ.",
      );
    },
  );

  api.onEvent(
    { componentType: "sidebar", descendantId: "iwe-day-close", eventType: "select" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        "Выполни `bash ~/iwe-platform/scripts/day-close.sh` — закрой день: план/факт, capture, commit + push.",
      );
    },
  );

  api.onEvent(
    { componentType: "sidebar", descendantId: "iwe-wp-new", eventType: "select" },
    async (_e: any, ctx: any) => {
      await ctx.pi.prompt(
        "Выполни `bash ~/iwe-platform/scripts/skills/wp-new.sh` — создай новый Work Package по инструкции скрипта.",
      );
    },
  );
}
