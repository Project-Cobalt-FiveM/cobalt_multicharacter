import { isRecord, list, num, str, strings } from './guards';

export type Org = { label: string; grade?: string };

export type Character = {
  citizenid: string;
  cid: number;
  charinfo: {
    firstname: string;
    lastname: string;
    birthdate?: string;
    gender?: number;
    nationality?: string;
  };
  money: { cash: number; bank: number };
  org: Org | null;
  isDead: boolean;
  lastPlayed?: number;
};

export type Selection = number | 'new';

export const SPAWN_KINDS = ['last', 'apartment', 'house', 'favorite'] as const;

export type SpawnKind = (typeof SPAWN_KINDS)[number];

export type SpawnId = string | number | null;

export type SpawnTarget = { kind: SpawnKind; id: SpawnId };

export type SpawnOption = SpawnTarget & {
  name: string;
  subtitle?: string;
  area?: string;
  postal?: string;
};

export type Locales = Record<string, string>;

export type CreationRules = {
  minYear: number;
  maxYear: number;
  blockedWords: string[];
  blockedFragments: string[];
  nationalities: string[];
};

export type OpenMessage = {
  characters: Character[];
  maxSlots: number;
  enableDelete: boolean;
  creation: CreationRules;
  locales: Locales;
};

export type NuiMessage =
  | ({ action: 'open' } & OpenMessage)
  | { action: 'close' }
  | { action: 'spawnOptions'; spawns: SpawnOption[] };

export type Gender = 0 | 1;

export type CreateForm = {
  firstname: string;
  lastname: string;
  nationality: string;
  birthdate: string;
  gender: Gender;
};

type Ok = 'ok';

export type NuiCallbacks = {
  ready: { args: Record<string, never>; result: Ok };
  previewPed: { args: { character: Character | null }; result: Ok };
  rotatePed: { args: { delta: number }; result: Ok };
  previewSpawn: { args: { citizenid: string; spawn: SpawnTarget }; result: Ok };
  spawnBack: { args: Record<string, never>; result: Ok };
  select: { args: { citizenid: string; spawn: SpawnTarget }; result: Ok };
  create: { args: CreateForm & { cid: number }; result: Ok };
  delete: { args: { citizenid: string }; result: Ok };
};

function toOrg(value: unknown): Org | null {
  if (!isRecord(value)) return null;

  const label = str(value.label);
  if (!label) return null;

  return { label, grade: str(value.grade) };
}

function toCharacter(value: unknown): Character | null {
  if (!isRecord(value) || !isRecord(value.charinfo)) return null;

  const citizenid = str(value.citizenid);
  const cid = num(value.cid);
  const firstname = str(value.charinfo.firstname);
  const lastname = str(value.charinfo.lastname);

  if (!citizenid || cid == null || firstname == null || lastname == null) return null;

  const money = isRecord(value.money) ? value.money : {};

  return {
    citizenid,
    cid,
    charinfo: {
      firstname,
      lastname,
      birthdate: str(value.charinfo.birthdate),
      gender: num(value.charinfo.gender),
      nationality: str(value.charinfo.nationality),
    },
    money: { cash: num(money.cash) ?? 0, bank: num(money.bank) ?? 0 },
    org: toOrg(value.org),
    isDead: value.isDead === true,
    lastPlayed: num(value.lastPlayed),
  };
}

function toSpawnOption(value: unknown): SpawnOption | null {
  if (!isRecord(value)) return null;

  const kind = SPAWN_KINDS.find((k) => k === value.kind);
  const name = str(value.name);

  if (!kind || !name) return null;

  return {
    kind,
    id: str(value.id) ?? num(value.id) ?? null,
    name,
    subtitle: str(value.subtitle),
    area: str(value.area),
    postal: str(value.postal),
  };
}

function toCreationRules(value: unknown): CreationRules {
  const rules = isRecord(value) ? value : {};

  return {
    minYear: num(rules.minYear) ?? 0,
    maxYear: num(rules.maxYear) ?? 0,
    blockedWords: strings(rules.blockedWords),
    blockedFragments: strings(rules.blockedFragments),
    nationalities: strings(rules.nationalities),
  };
}

function toLocales(value: unknown): Locales {
  const locales: Locales = {};
  if (!isRecord(value)) return locales;

  for (const [key, text] of Object.entries(value)) {
    if (typeof text === 'string') locales[key] = text;
  }

  return locales;
}

function toOpenMessage(value: Record<string, unknown>): OpenMessage {
  return {
    characters: list(value.characters)
      .map(toCharacter)
      .filter((c): c is Character => c != null),
    maxSlots: num(value.maxSlots) ?? 5,
    enableDelete: value.enableDelete !== false,
    creation: toCreationRules(value.creation),
    locales: toLocales(value.locales),
  };
}

export function toNuiMessage(value: unknown): NuiMessage | null {
  if (!isRecord(value)) return null;

  switch (value.action) {
    case 'open':
      return { action: 'open', ...toOpenMessage(value) };
    case 'close':
      return { action: 'close' };
    case 'spawnOptions':
      return {
        action: 'spawnOptions',
        spawns: list(value.spawns)
          .map(toSpawnOption)
          .filter((s): s is SpawnOption => s != null),
      };
    default:
      return null;
  }
}
