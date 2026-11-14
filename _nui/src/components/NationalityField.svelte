<script lang="ts">
  import { t } from '../lib/locale.svelte';
  import { inputClass } from '../lib/ui';

  interface Props {
    id: string;
    options: readonly string[];
    onchange: (value: string) => void;
  }

  let { id, options, onchange }: Props = $props();

  let query = $state('');
  let open = $state(false);
  let active = $state(0);

  const needle = $derived(query.trim().toLowerCase());
  const matches = $derived(options.filter((n) => n.toLowerCase().includes(needle)).slice(0, 6));

  function choose(name: string): void {
    onchange(name);
    query = name;
    open = false;
  }

  function commit(): void {
    choose(options.find((n) => n.toLowerCase() === needle) ?? '');
  }

  function oninput(): void {
    open = true;
    active = 0;
  }

  function onkeydown(event: KeyboardEvent): void {
    if (!open && event.key === 'ArrowDown') open = true;
    if (!open) return;

    const highlighted = matches[active];

    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      const step = event.key === 'ArrowDown' ? 1 : -1;
      active = (active + step + matches.length) % Math.max(matches.length, 1);
    } else if (event.key === 'Enter' && highlighted) {
      event.preventDefault();
      choose(highlighted);
    } else if (event.key === 'Escape') {
      event.stopPropagation();
      open = false;
    }
  }
</script>

<div class="relative">
  <input
    {id}
    class={inputClass}
    role="combobox"
    aria-expanded={open}
    aria-controls="{id}-list"
    autocomplete="off"
    placeholder={t('ui.create.nationality_placeholder')}
    bind:value={query}
    {oninput}
    onfocus={() => (open = true)}
    onblur={commit}
    {onkeydown}
  />
  {#if open && matches.length > 0}
    <ul id="{id}-list" role="listbox" class="absolute inset-x-0 top-[calc(100%+0.25rem)] z-[1] animate-pop list-none rounded-lg border border-border bg-popover p-1">
      {#each matches as name, i (name)}
        <li role="option" aria-selected={i === active}>
          <button
            type="button"
            tabindex="-1"
            onmousedown={(event) => {
              event.preventDefault();
              choose(name);
            }}
            class="h-8 w-full rounded-sm px-2 text-left text-sm hover:bg-muted {i === active ? 'bg-muted' : ''}"
          >
            {name}
          </button>
        </li>
      {/each}
    </ul>
  {/if}
</div>
