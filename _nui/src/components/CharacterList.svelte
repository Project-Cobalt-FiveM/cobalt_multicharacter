<script lang="ts">
  import PlusIcon from 'phosphor-svelte/lib/PlusIcon';
  import { fullName, role } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { app } from '../lib/select.svelte';
  import type { Selection } from '../lib/types';
  import { focusRing, motion } from '../lib/ui';
  import Rail from './Rail.svelte';
  import RailItem from './RailItem.svelte';

  const isNew = $derived(app.selected === 'new');

  function pick(key: Selection): void {
    if (key !== app.selected) app.select(key);
  }
</script>

<Rail label={t('ui.characters.title')} count={t('ui.characters.count', app.characters.length, app.maxSlots)}>
  {#each app.characters as character (character.citizenid)}
    <RailItem
      active={app.selected === character.cid}
      title={fullName(character)}
      detail={role(character)}
      onclick={() => pick(character.cid)}
    />
  {/each}

  {#snippet footer()}
    {#if app.freeSlots > 0}
      <hr class="mt-3 mb-5 border-0 border-t border-rule" />
      <button
        type="button"
        aria-pressed={isNew}
        onclick={() => pick('new')}
        class="group flex h-9 items-center gap-2.5 rounded-md px-3 {motion} {focusRing} {isNew
          ? 'bg-cobalt text-foreground'
          : 'text-muted-foreground hover:bg-muted'}"
      >
        <PlusIcon size={14} weight="fill" />
        <span class="text-[0.9375rem] leading-5 font-medium {motion} {isNew ? 'text-foreground' : 'text-soft group-hover:text-foreground'}">
          {t('ui.characters.new')}
        </span>
        <span class="text-13 tabular-nums {motion} {isNew ? 'text-foreground' : 'text-muted-foreground'}">
          {t(app.freeSlots === 1 ? 'ui.characters.free_one' : 'ui.characters.free_other', app.freeSlots)}
        </span>
      </button>
    {/if}
  {/snippet}
</Rail>
