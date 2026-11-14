<script lang="ts">
  import ArrowLeftIcon from 'phosphor-svelte/lib/ArrowLeftIcon';
  import { t } from '../lib/locale.svelte';
  import { app } from '../lib/select.svelte';
  import type { SpawnKind, SpawnOption } from '../lib/types';
  import Button from './Button.svelte';
  import DetailPanel, { type Stat } from './DetailPanel.svelte';
  import Rail from './Rail.svelte';
  import RailItem from './RailItem.svelte';

  const current = $derived(app.spawnOptions[app.spawnIndex]);
  const count = $derived(app.spawnOptions.length);

  function kindLabel(kind: SpawnKind): string {
    return t(`ui.spawn.kind.${kind}`);
  }

  function railDetail(option: SpawnOption): string {
    return option.area && option.area !== option.name ? option.area : kindLabel(option.kind);
  }

  function statsOf(option: SpawnOption): Stat[] {
    return [
      { label: t('ui.spawn.area'), value: option.area ?? t('ui.unknown') },
      ...(option.postal ? [{ label: t('ui.spawn.postal'), value: option.postal, numeric: true }] : []),
      { label: t('ui.spawn.type'), value: kindLabel(option.kind) },
    ];
  }
</script>

<Rail label={t('ui.spawn.title')} count={t(count === 1 ? 'ui.spawn.count_one' : 'ui.spawn.count_other', count)}>
  {#each app.spawnOptions as option, i (`${option.kind}:${option.id}`)}
    <RailItem
      active={i === app.spawnIndex}
      title={option.name}
      detail={railDetail(option)}
      onclick={() => app.previewSpawn(i)}
      ondblclick={() => app.spawn(option)}
    />
  {/each}
</Rail>

<DetailPanel contentKey={String(app.spawnIndex)} title={current?.name ?? ''} subtitle={current?.subtitle} stats={current && statsOf(current)}>
  {#snippet actions()}
    <Button onclick={() => app.backToCharacters()}>
      <ArrowLeftIcon size={16} weight="fill" />
      {t('ui.spawn.back')}
    </Button>
    <Button variant="primary" class="flex-1" disabled={!current} onclick={() => app.spawn(current)}>{t('ui.spawn.action')}</Button>
  {/snippet}
</DetailPanel>
