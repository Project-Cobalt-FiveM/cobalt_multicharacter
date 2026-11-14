<script lang="ts">
  import { focusRing, motion } from '../lib/ui';

  interface Props {
    active: boolean;
    title: string;
    detail: string;
    onclick: () => void;
    ondblclick?: () => void;
  }

  let { active, title, detail, onclick, ondblclick }: Props = $props();
</script>

<button
  type="button"
  role="option"
  aria-selected={active}
  {onclick}
  {ondblclick}
  class="group flex h-[3.25rem] shrink-0 items-center rounded-md px-3 text-left {motion} {focusRing} {active ? 'bg-cobalt' : 'hover:bg-muted'}"
>
  <span class="flex min-w-0 flex-col">
    <span
      class="truncate text-xl leading-[1.625rem] tracking-[-0.01em] {motion} {active
        ? 'font-semibold text-foreground'
        : 'font-medium text-soft group-hover:text-foreground'}"
    >
      {title}
    </span>
    <span class="truncate text-13 leading-[1.125rem] {motion} {active ? 'text-foreground' : 'text-muted-foreground'}">{detail}</span>
  </span>
</button>
