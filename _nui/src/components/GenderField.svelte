<script lang="ts">
  import { t } from '../lib/locale.svelte';
  import type { Gender } from '../lib/types';
  import { focusRing, motion } from '../lib/ui';

  let { value = $bindable() }: { value: Gender } = $props();

  const genders: readonly { value: Gender; label: string }[] = [
    { value: 0, label: 'ui.create.male' },
    { value: 1, label: 'ui.create.female' },
  ];
</script>

<div class="grid grid-cols-2 gap-1 rounded-lg bg-muted p-1" role="radiogroup" aria-label={t('ui.create.gender')}>
  {#each genders as option (option.value)}
    {@const active = value === option.value}
    <button
      type="button"
      role="radio"
      aria-checked={active}
      onclick={() => (value = option.value)}
      class="h-7 rounded-sm text-sm font-medium {motion} {focusRing} {active ? 'bg-cobalt text-foreground' : 'text-muted-foreground hover:text-foreground'}"
    >
      {t(option.label)}
    </button>
  {/each}
</div>
