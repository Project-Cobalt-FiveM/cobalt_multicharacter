import type { Attachment } from 'svelte/attachments';

export const focusRing = 'outline-none focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cobalt';

export const motion = 'transition-colors duration-150 ease-cobalt';

export const focusOnMount: Attachment<HTMLElement> = (node) => {
  node.focus();
};

export const inputClass =
  'h-9 w-full rounded-md border border-input bg-transparent px-3 text-sm outline-none transition-[border-color] duration-150 ease-cobalt placeholder:text-muted-foreground focus-visible:border-cobalt';
