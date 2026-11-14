<script lang="ts">
  import { onMount } from 'svelte';
  import CharacterDetail from './components/CharacterDetail.svelte';
  import CharacterList from './components/CharacterList.svelte';
  import CreateDialog from './components/CreateDialog.svelte';
  import DeleteDialog from './components/DeleteDialog.svelte';
  import Footer, { type Hint } from './components/Footer.svelte';
  import SpawnRail from './components/SpawnRail.svelte';
  import { t } from './lib/locale.svelte';
  import { inGame, nui, onNuiMessage } from './lib/nui';
  import { app } from './lib/select.svelte';

  const ROTATE_SCALE = 0.4;

  let dragX: number | null = null;
  let pending = 0;
  let frame = 0;
  let dragging = $state(false);

  const hints = $derived<Hint[]>(
    app.screen === 'spawn'
      ? [
          { key: '↑ ↓', label: t('ui.hint.browse') },
          { key: t('ui.key.enter'), label: t('ui.spawn.action') },
        ]
      : [
          { key: '↑ ↓', label: t('ui.hint.browse') },
          { key: t('ui.key.enter'), label: t(app.character ? 'ui.hint.play' : 'ui.hint.create') },
          { key: t('ui.key.drag'), label: t('ui.hint.rotate') },
        ],
  );

  const cursor = $derived(app.screen === 'characters' ? (dragging ? 'cursor-grabbing' : 'cursor-grab') : '');

  const keyActions: Record<string, () => void> = {
    ArrowUp: () => (app.screen === 'spawn' ? app.stepSpawn(-1) : app.browse(-1)),
    ArrowDown: () => (app.screen === 'spawn' ? app.stepSpawn(1) : app.browse(1)),
    Enter: () => app.confirm(),
  };

  function onkeydown(event: KeyboardEvent): void {
    if (!app.visible) return;

    if (app.dialog) {
      if (event.key === 'Escape') app.dialog = null;
      return;
    }

    const target = event.target;
    const actionButton = target instanceof HTMLButtonElement && !target.matches('[role="option"], [aria-pressed]');
    if (event.key === 'Enter' && actionButton) return;

    const action = keyActions[event.key];
    if (!action) return;

    event.preventDefault();
    action();
  }

  function onpointerdown(event: PointerEvent & { currentTarget: HTMLElement }): void {
    if (app.screen !== 'characters' || event.target !== event.currentTarget) return;

    dragX = event.clientX;
    dragging = true;
    event.currentTarget.setPointerCapture(event.pointerId);
  }

  function onpointermove(event: PointerEvent): void {
    if (dragX == null) return;

    pending += event.clientX - dragX;
    dragX = event.clientX;

    frame ||= requestAnimationFrame(() => {
      void nui('rotatePed', { delta: pending * ROTATE_SCALE });
      pending = 0;
      frame = 0;
    });
  }

  function onpointerup(): void {
    dragX = null;
    dragging = false;
  }

  onMount(() => {
    const stop = onNuiMessage((message) => {
      if (message.action === 'open') app.open(message);
      else if (message.action === 'close') app.close();
      else app.spawnOptions = message.spawns;
    });

    if (inGame) void nui('ready', {});

    return stop;
  });
</script>

<svelte:window {onkeydown} />

{#if app.visible}
  <div class="font-sans text-foreground">
    <main class="fixed inset-0 *:cursor-auto {cursor}" {onpointerdown} {onpointermove} {onpointerup} onpointercancel={onpointerup}>
      {#if app.screen === 'characters'}
        <CharacterList />
        <CharacterDetail />
      {:else}
        <SpawnRail />
      {/if}

      <Footer {hints} />
    </main>

    {#if app.dialog === 'create'}
      <CreateDialog rules={app.creation} onconfirm={(form) => app.create(form)} onclose={() => (app.dialog = null)} />
    {:else if app.dialog === 'delete' && app.character}
      <DeleteDialog character={app.character} onconfirm={() => app.remove()} onclose={() => (app.dialog = null)} />
    {/if}
  </div>
{/if}
