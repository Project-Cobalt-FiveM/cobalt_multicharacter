<script lang="ts">
  import XIcon from 'phosphor-svelte/lib/XIcon';
  import type { Snippet } from 'svelte';
  import { t } from '../lib/locale.svelte';
  import { focusRing, motion } from '../lib/ui';

  interface Props {
    title: string;
    onclose: () => void;
    children: Snippet;
  }

  let { title, onclose, children }: Props = $props();
</script>

<div class="fixed inset-0 z-10 flex items-center justify-center">
  <div role="dialog" aria-modal="true" aria-label={title} class="w-[28rem] max-w-[calc(100vw-3rem)] animate-pop rounded-lg border border-border bg-popover p-6">
    <header class="mb-5 flex items-center justify-between">
      <h2 class="text-base leading-6 font-semibold">{title}</h2>
      <button
        type="button"
        aria-label={t('ui.close')}
        onclick={onclose}
        class="flex size-8 items-center justify-center rounded-md text-muted-foreground hover:bg-muted hover:text-foreground {motion} {focusRing}"
      >
        <XIcon size={16} weight="fill" />
      </button>
    </header>
    {@render children()}
  </div>
</div>
