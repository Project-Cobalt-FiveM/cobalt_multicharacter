<script lang="ts">
  import type { Snippet } from 'svelte';
  import type { HTMLButtonAttributes } from 'svelte/elements';
  import { focusRing } from '../lib/ui';

  type Variant = 'primary' | 'secondary' | 'destructive';

  interface Props extends HTMLButtonAttributes {
    variant?: Variant;
    small?: boolean;
    children: Snippet;
  }

  let { variant = 'secondary', small = false, class: extra = '', type = 'button', children, ...rest }: Props = $props();

  const variants: Record<Variant, string> = {
    primary: 'bg-cobalt text-foreground enabled:hover:bg-cobalt-hover',
    secondary: 'bg-secondary text-foreground enabled:hover:bg-input',
    destructive: 'bg-destructive-solid text-foreground enabled:hover:bg-destructive-solid-hover',
  };

  const size = $derived(small ? 'h-9 px-4 text-sm font-medium' : 'h-[3.25rem] px-6 text-base font-semibold');
</script>

<button
  {type}
  class="inline-flex items-center justify-center gap-2 rounded-md whitespace-nowrap transition-[background-color,scale] duration-150 ease-cobalt enabled:active:scale-[0.98] disabled:cursor-not-allowed disabled:bg-secondary disabled:text-muted-foreground {size} {variants[
    variant
  ]} {focusRing} {extra}"
  {...rest}
>
  {@render children()}
</button>
