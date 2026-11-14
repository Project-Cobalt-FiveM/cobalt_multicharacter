<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    label: string;
    count: string;
    children: Snippet;
    footer?: Snippet;
  }

  let { label, count, children, footer }: Props = $props();
</script>

<nav class="absolute top-[6rem] left-[6rem] flex w-[24.25rem] animate-enter flex-col rounded-lg border border-border bg-card p-6" aria-label={label}>
  <header class="mb-7 flex justify-between px-3 text-13 leading-4 font-medium text-soft">
    <span>{label}</span>
    <span class="text-muted-foreground tabular-nums">{count}</span>
  </header>

  <div class="flex max-h-[calc(100vh-25rem)] flex-col gap-1 overflow-y-auto" role="listbox" aria-label={label}>
    {@render children()}
  </div>

  {@render footer?.()}
</nav>
