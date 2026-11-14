<script lang="ts">
  import { t } from '../lib/locale.svelte';
  import { inputClass } from '../lib/ui';

  interface Props {
    id: string;
    minYear: number;
    maxYear: number;
    onchange: (value: string) => void;
  }

  let { id, minYear, maxYear, onchange }: Props = $props();

  let day = $state('');
  let month = $state('');
  let year = $state('');

  function digits(value: string, max: number): string {
    return value.replace(/\D/g, '').slice(0, max);
  }

  function toIsoDate(): string {
    const d = Number(day);
    const m = Number(month);
    const y = Number(year);
    const date = new Date(Date.UTC(y, m - 1, d));
    const real = date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d;

    if (!real || y < minYear || y > maxYear) return '';

    return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
  }

  function update(): void {
    onchange(toIsoDate());
  }
</script>

<div class="grid grid-cols-[1fr_1fr_2fr] gap-2">
  <input
    {id}
    class="{inputClass} tabular-nums"
    inputmode="numeric"
    placeholder={t('ui.create.day_placeholder')}
    aria-label={t('ui.create.day')}
    bind:value={() => day, (v) => ((day = digits(v, 2)), update())}
  />
  <input
    class="{inputClass} tabular-nums"
    inputmode="numeric"
    placeholder={t('ui.create.month_placeholder')}
    aria-label={t('ui.create.month')}
    bind:value={() => month, (v) => ((month = digits(v, 2)), update())}
  />
  <input
    class="{inputClass} tabular-nums"
    inputmode="numeric"
    placeholder={t('ui.create.year_placeholder')}
    aria-label={t('ui.create.year')}
    bind:value={() => year, (v) => ((year = digits(v, 4)), update())}
  />
</div>
