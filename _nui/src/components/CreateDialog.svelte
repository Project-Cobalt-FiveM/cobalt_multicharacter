<script lang="ts">
  import { t } from '../lib/locale.svelte';
  import type { CreateForm, CreationRules, Gender } from '../lib/types';
  import { focusOnMount, inputClass } from '../lib/ui';
  import BirthdateField from './BirthdateField.svelte';
  import Button from './Button.svelte';
  import Dialog from './Dialog.svelte';
  import GenderField from './GenderField.svelte';
  import NationalityField from './NationalityField.svelte';

  type Errors = Partial<Record<'firstname' | 'lastname' | 'nationality' | 'birthdate', string>>;

  interface Props {
    rules: CreationRules;
    onconfirm: (form: CreateForm) => Promise<void>;
    onclose: () => void;
  }

  let { rules, onconfirm, onclose }: Props = $props();

  let firstname = $state('');
  let lastname = $state('');
  let nationality = $state('');
  let birthdate = $state('');
  let gender = $state<Gender>(0);
  let errors = $state<Errors>({});
  let submitting = $state(false);

  function nameError(raw: string, missing: string): string | undefined {
    const name = raw.trim();

    if (!name) return missing;
    if (/[^a-zA-Z\s\-']/.test(name)) return t('ui.create.name_characters');

    const lowered = name.toLowerCase();
    const words = lowered.split(/[\s\-']+/);
    const blocked =
      rules.blockedFragments.some((fragment) => lowered.includes(fragment.toLowerCase())) ||
      rules.blockedWords.some((word) => words.includes(word.toLowerCase()));

    if (blocked) return t('ui.create.name_blocked');
  }

  function validate(): Errors {
    const found: Errors = {};
    const first = nameError(firstname, t('ui.create.firstname_missing'));
    const last = nameError(lastname, t('ui.create.lastname_missing'));

    if (first) found.firstname = first;
    if (last) found.lastname = last;
    if (!nationality) found.nationality = t('ui.create.nationality_missing');
    if (!birthdate) found.birthdate = t('ui.create.birthdate_invalid', rules.minYear, rules.maxYear);

    return found;
  }

  async function submit(event: SubmitEvent): Promise<void> {
    event.preventDefault();

    errors = validate();
    if (Object.keys(errors).length) return;

    submitting = true;
    await onconfirm({ firstname: firstname.trim(), lastname: lastname.trim(), nationality, birthdate, gender });
    submitting = false;
  }
</script>

{#snippet error(message: string | undefined)}
  {#if message}
    <span class="text-xs text-destructive">{message}</span>
  {/if}
{/snippet}

<Dialog title={t('ui.create.action')} {onclose}>
  <form class="flex flex-col gap-4" onsubmit={submit}>
    <div class="grid grid-cols-2 gap-3">
      <label class="flex flex-col gap-1.5">
        <span class="text-sm font-medium text-soft">{t('ui.create.firstname')}</span>
        <input class={inputClass} bind:value={firstname} maxlength={20} autocomplete="off" placeholder={t('ui.create.firstname_placeholder')} {@attach focusOnMount} />
        {@render error(errors.firstname)}
      </label>
      <label class="flex flex-col gap-1.5">
        <span class="text-sm font-medium text-soft">{t('ui.create.lastname')}</span>
        <input class={inputClass} bind:value={lastname} maxlength={20} autocomplete="off" placeholder={t('ui.create.lastname_placeholder')} />
        {@render error(errors.lastname)}
      </label>
    </div>

    <div class="flex flex-col gap-1.5">
      <label class="text-sm font-medium text-soft" for="nationality">{t('ui.create.nationality')}</label>
      <NationalityField id="nationality" options={rules.nationalities} onchange={(value) => (nationality = value)} />
      {@render error(errors.nationality)}
    </div>

    <div class="flex flex-col gap-1.5">
      <label class="text-sm font-medium text-soft" for="birthdate">{t('ui.create.birthdate')}</label>
      <BirthdateField id="birthdate" minYear={rules.minYear} maxYear={rules.maxYear} onchange={(value) => (birthdate = value)} />
      {@render error(errors.birthdate)}
    </div>

    <div class="flex flex-col gap-1.5">
      <span class="text-sm font-medium text-soft">{t('ui.create.gender')}</span>
      <GenderField bind:value={gender} />
    </div>

    <div class="mt-2 flex justify-end gap-2">
      <Button small onclick={onclose}>{t('ui.cancel')}</Button>
      <Button small variant="primary" type="submit" disabled={submitting}>
        {submitting ? t('ui.create.submitting') : t('ui.create.action')}
      </Button>
    </div>
  </form>
</Dialog>
