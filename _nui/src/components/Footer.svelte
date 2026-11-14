<script lang="ts" module>
  export type Hint = { key: string; label: string };
</script>

<script lang="ts">
  let { hints }: { hints: Hint[] } = $props();
</script>

<footer class="pointer-events-none absolute right-[6rem] bottom-[4rem] left-[6rem] flex animate-enter items-center justify-between">
  <div class="flex gap-[1.625rem] rounded-lg border border-border bg-card px-4 py-2.5">
    {#each hints as hint (hint.label)}
      <span class="inline-flex items-center gap-[0.6875rem] text-[0.9375rem] leading-[1.375rem] text-muted-foreground">
        <kbd class="inline-flex h-[1.625rem] items-center rounded-sm border border-border bg-muted px-2 py-1 font-sans text-13 font-medium text-foreground">
          {hint.key}
        </kbd>
        {hint.label}
      </span>
    {/each}
  </div>

  <div class="flex items-center gap-3 rounded-lg border border-border bg-card px-4 py-2">
    <svg viewBox="0 0 120 120" fill="none" aria-hidden="true" class="size-9">
      <path d="M14 14 L44 36 L60 44 L76 36 L106 14 L101 74 C100 96 84 108 60 108 C36 108 20 96 19 74 Z" fill="#FAFAFA" />
      <path d="M53.2 52.8 A13 13 0 1 0 53.2 71.2" stroke="#0A0A0A" stroke-width="7" stroke-linecap="round" />
      <circle cx="76" cy="62" r="12" stroke="#0A0A0A" stroke-width="7" />
      <circle cx="76" cy="62" r="4.5" fill="#5078D7" />
      <path d="M55.5 79 L64.5 79 L60 87 Z" fill="#0A0A0A" />
    </svg>
    <span class="text-xl font-semibold tracking-[-0.02em]">Cobalt</span>
  </div>
</footer>
