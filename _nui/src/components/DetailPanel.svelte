<script lang="ts" module>
  export type Stat = { label: string; value: string; numeric?: boolean };
</script>

<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    contentKey: string;
    title: string;
    subtitle?: string;
    stats?: Stat[];
    actions: Snippet;
  }

  let { contentKey, title, subtitle, stats, actions }: Props = $props();
</script>

<section class="absolute right-[6rem] bottom-[10.5rem] flex w-[31.75rem] animate-enter flex-col gap-7 rounded-lg border border-border bg-card p-6">
  {#key contentKey}
    <div class="flex animate-fade flex-col gap-7" aria-live="polite">
      <div class="flex flex-col gap-2">
        <h1 class="text-[3.5rem] leading-[3.75rem] font-semibold tracking-[-0.03em] break-words text-foreground">{title}</h1>
        {#if subtitle}
          <p class="text-[1.0625rem] leading-[1.625rem] text-muted-foreground">{subtitle}</p>
        {/if}
      </div>

      {#if stats}
        <dl class="flex gap-10 border-t border-rule pt-5">
          {#each stats as stat (stat.label)}
            <div class="flex min-w-0 flex-col gap-0.5">
              <dt class="text-13 leading-4 font-medium text-muted-foreground">{stat.label}</dt>
              <dd class="text-base leading-6 font-medium whitespace-nowrap text-foreground {stat.numeric ? 'tabular-nums' : ''}">
                {stat.value}
              </dd>
            </div>
          {/each}
        </dl>
      {/if}
    </div>
  {/key}

  <div class="flex gap-2">{@render actions()}</div>
</section>
