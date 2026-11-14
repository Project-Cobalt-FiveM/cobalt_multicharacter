import { isRecord } from './guards';
import { dispatch, installMock } from './nui';
import { app } from './select.svelte';
import type { Locales, OpenMessage, SpawnOption } from './types';

const localeFiles = import.meta.glob<unknown>('../../../locales/en.json', { eager: true, import: 'default' });
const nationalityFiles = import.meta.glob<string[]>('../../../data/nationalities.json', { eager: true, import: 'default' });

function flatten(tree: unknown, prefix = '', into: Locales = {}): Locales {
  if (typeof tree === 'string') {
    into[prefix] = tree;
    return into;
  }

  if (!isRecord(tree)) return into;

  for (const [key, value] of Object.entries(tree)) {
    flatten(value, prefix ? `${prefix}.${key}` : key, into);
  }

  return into;
}

const daysAgo = (n: number): number => Math.floor((Date.now() - n * 86400000) / 1000);

const open: OpenMessage = {
  maxSlots: 5,
  enableDelete: true,
  creation: {
    minYear: 1940,
    maxYear: 2008,
    blockedWords: ['ass'],
    blockedFragments: ['fuck'],
    nationalities: Object.values(nationalityFiles)[0] ?? [],
  },
  locales: flatten(Object.values(localeFiles)[0]),
  characters: [
    {
      citizenid: 'DS1995',
      cid: 1,
      charinfo: { firstname: 'Donovan', lastname: 'Sinclair', birthdate: '1995-12-14', gender: 0, nationality: 'American' },
      money: { cash: 500, bank: 5000 },
      org: null,
      isDead: false,
      lastPlayed: daysAgo(2),
    },
    {
      citizenid: 'MR2001',
      cid: 2,
      charinfo: { firstname: 'Maya', lastname: 'Reyes', birthdate: '2001-04-03', gender: 1, nationality: 'Mexican' },
      money: { cash: 1250, bank: 48200 },
      org: { label: 'LSPD', grade: 'Officer' },
      isDead: false,
      lastPlayed: daysAgo(9),
    },
  ],
};

const spawns: SpawnOption[] = [
  { kind: 'last', id: null, name: 'Last location', subtitle: 'Where you logged out', area: 'Legion Square', postal: '214' },
  { kind: 'apartment', id: 'pink_cage', name: 'Pink Cage Motel', subtitle: 'Your starter room', area: 'Alta', postal: '578' },
  { kind: 'favorite', id: 0, name: 'Legion Square', subtitle: 'The heart of downtown Los Santos', area: 'Legion Square', postal: '214' },
  { kind: 'favorite', id: 1, name: 'Airport', subtitle: 'Los Santos International Airport', area: 'Los Santos International Airport', postal: '112' },
  { kind: 'favorite', id: 2, name: 'Vespucci Beach', subtitle: 'The sunny boardwalk along the coast', area: 'Vespucci Beach', postal: '305' },
  { kind: 'favorite', id: 3, name: 'Sandy Shores', subtitle: 'A quiet desert town in Blaine County', area: 'Sandy Shores', postal: '842' },
  { kind: 'favorite', id: 4, name: 'Paleto Bay', subtitle: 'Peaceful coastal town up north', area: 'Paleto Bay', postal: '1063' },
];

installMock({
  ready: () => 'ok',
  previewPed: () => 'ok',
  rotatePed: () => 'ok',
  previewSpawn: () => 'ok',
  spawnBack: () => 'ok',
  select: () => 'ok',
  create: () => 'ok',
  delete: () => 'ok',
});

const params = new URLSearchParams(window.location.search);
const background = params.get('bg');
document.body.style.background = background ? `url(${background}) center / cover no-repeat fixed` : '#1B2030';

dispatch({ action: 'spawnOptions', spawns });
dispatch({ action: 'open', ...open });

if (params.get('select') === 'new') app.select('new');
if (params.get('screen') === 'spawn') app.play();

const preset = params.get('dialog');
if (preset === 'create' || preset === 'delete') app.dialog = preset;
