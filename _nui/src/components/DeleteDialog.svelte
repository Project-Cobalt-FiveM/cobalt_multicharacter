<script lang="ts">
  import { fullName } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { Character } from '../lib/types';
  import Button from './Button.svelte';
  import Dialog from './Dialog.svelte';

  interface Props {
    character: Character;
    onconfirm: () => Promise<void>;
    onclose: () => void;
  }

  let { character, onconfirm, onclose }: Props = $props();

  let deleting = $state(false);

  async function confirm(): Promise<void> {
    deleting = true;
    await onconfirm();
    deleting = false;
  }
</script>

<Dialog title={t('ui.delete.action')} {onclose}>
  <p class="text-sm leading-5 text-muted-foreground">{t('ui.delete.confirm', fullName(character))}</p>

  <div class="mt-6 flex justify-end gap-2">
    <Button small onclick={onclose}>{t('ui.cancel')}</Button>
    <Button small variant="destructive" disabled={deleting} onclick={confirm}>
      {deleting ? t('ui.delete.submitting') : t('ui.delete.action')}
    </Button>
  </div>
</Dialog>
