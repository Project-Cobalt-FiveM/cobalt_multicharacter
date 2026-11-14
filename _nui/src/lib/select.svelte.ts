import { setLocales } from './locale.svelte';
import { nui } from './nui';
import type { Character, CreateForm, CreationRules, OpenMessage, Selection, SpawnOption, SpawnTarget } from './types';

export type Screen = 'characters' | 'spawn';

export type DialogKind = 'create' | 'delete' | null;

function wrap(index: number, length: number): number {
  return length === 0 ? 0 : (index + length) % length;
}

class CharacterSelect {
  visible = $state(false);
  screen = $state<Screen>('characters');
  dialog = $state<DialogKind>(null);
  characters = $state<Character[]>([]);
  maxSlots = $state(5);
  enableDelete = $state(true);
  creation = $state.raw<CreationRules>({ minYear: 0, maxYear: 0, blockedWords: [], blockedFragments: [], nationalities: [] });
  selected = $state<Selection | null>(null);
  spawnOptions = $state<SpawnOption[]>([]);
  spawnIndex = $state(0);

  character = $derived(this.characters.find((c) => c.cid === this.selected) ?? null);
  freeSlots = $derived(this.maxSlots - this.characters.length);
  order = $derived<Selection[]>([...this.characters.map((c) => c.cid), ...(this.freeSlots > 0 ? ['new' as const] : [])]);

  open(message: OpenMessage): void {
    setLocales(message.locales);
    this.characters = message.characters;
    this.maxSlots = message.maxSlots;
    this.enableDelete = message.enableDelete;
    this.creation = message.creation;
    this.screen = 'characters';
    this.dialog = null;
    this.visible = true;
    this.select(message.characters[0]?.cid ?? 'new');
  }

  close(): void {
    this.visible = false;
  }

  select(key: Selection): void {
    this.selected = key;
    void nui('previewPed', { character: $state.snapshot(this.characters.find((c) => c.cid === key)) ?? null });
  }

  browse(delta: number): void {
    const index = this.selected == null ? -1 : this.order.indexOf(this.selected);
    const next = this.order[wrap(index + delta, this.order.length)];
    if (next != null) this.select(next);
  }

  previewSpawn(index: number): void {
    const option = this.spawnOptions[index];
    if (!option || !this.character) return;

    this.spawnIndex = index;
    void nui('previewSpawn', { citizenid: this.character.citizenid, spawn: { kind: option.kind, id: option.id } });
  }

  stepSpawn(delta: number): void {
    this.previewSpawn(wrap(this.spawnIndex + delta, this.spawnOptions.length));
  }

  spawn(target: SpawnTarget | undefined): void {
    if (!this.character || !target) return;

    void nui('select', { citizenid: this.character.citizenid, spawn: { kind: target.kind, id: target.id } });
    this.visible = false;
  }

  play(): void {
    if (!this.character) return;

    if (this.character.isDead) {
      this.spawn({ kind: 'last', id: null });
      return;
    }

    this.screen = 'spawn';
    this.previewSpawn(0);
  }

  backToCharacters(): void {
    this.screen = 'characters';
    void nui('spawnBack', {});
  }

  firstFreeCid(): number | undefined {
    for (let cid = 1; cid <= this.maxSlots; cid++) {
      if (!this.characters.some((c) => c.cid === cid)) return cid;
    }
  }

  async create(form: CreateForm): Promise<void> {
    const cid = this.firstFreeCid();
    if (cid == null) return;

    await nui('create', { ...form, cid });
    this.dialog = null;
  }

  async remove(): Promise<void> {
    if (!this.character) return;

    await nui('delete', { citizenid: this.character.citizenid });
    this.dialog = null;
  }

  confirm(): void {
    if (this.screen === 'spawn') {
      this.spawn(this.spawnOptions[this.spawnIndex]);
      return;
    }

    if (this.character) this.play();
    else this.dialog = 'create';
  }
}

export const app = new CharacterSelect();
