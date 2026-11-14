<script lang="ts">
  import TrashIcon from 'phosphor-svelte/lib/TrashIcon';
  import { birthdate, fullName, lastPlayed, money, role } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import { app } from '../lib/select.svelte';
  import type { Character } from '../lib/types';
  import Button from './Button.svelte';
  import DetailPanel from './DetailPanel.svelte';

  function subtitleOf(character: Character): string {
    const played = lastPlayed(character.lastPlayed);
    if (!played) return t('ui.character.subtitle', role(character));

    return t('ui.character.subtitle_played', role(character), played);
  }
</script>

{#if app.character}
  {@const character = app.character}
  <DetailPanel
    contentKey={character.citizenid}
    title={fullName(character)}
    subtitle={subtitleOf(character)}
    stats={[
      { label: t('ui.character.born'), value: birthdate(character.charinfo.birthdate), numeric: true },
      { label: t('ui.character.cash'), value: money(character.money.cash), numeric: true },
      { label: t('ui.character.bank'), value: money(character.money.bank), numeric: true },
      { label: t('ui.character.nationality'), value: character.charinfo.nationality || t('ui.unknown') },
    ]}
  >
    {#snippet actions()}
      <Button variant="primary" class="flex-1" onclick={() => app.play()}>{t('ui.character.play', character.charinfo.firstname)}</Button>
      {#if app.enableDelete}
        <Button
          variant="destructive"
          class="w-[3.25rem] !px-0"
          aria-label={t('ui.character.delete', character.charinfo.firstname)}
          onclick={() => (app.dialog = 'delete')}
        >
          <TrashIcon size={18} weight="fill" />
        </Button>
      {/if}
    {/snippet}
  </DetailPanel>
{:else}
  <DetailPanel contentKey="new" title={t('ui.characters.new')} subtitle={t('ui.character.new_subtitle')}>
    {#snippet actions()}
      <Button variant="primary" class="flex-1" onclick={() => (app.dialog = 'create')}>{t('ui.create.action')}</Button>
    {/snippet}
  </DetailPanel>
{/if}
