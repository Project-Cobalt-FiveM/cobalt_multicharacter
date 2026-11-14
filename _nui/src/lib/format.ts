import { t } from './locale.svelte';
import type { Character } from './types';

export function money(amount: number): string {
  return '$' + amount.toLocaleString('en-US');
}

export function birthdate(iso: string | undefined): string {
  const [y, m, d] = String(iso ?? '').split('-').map(Number);
  if (!y || !m || !d) return t('ui.unknown');

  return new Date(Date.UTC(y, m - 1, d)).toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    timeZone: 'UTC',
  });
}

export function role(character: Character): string {
  const org = character.org;
  if (!org) return t('ui.character.civilian');

  return org.grade ? `${org.label} ${org.grade}` : org.label;
}

export function fullName(character: Character): string {
  return `${character.charinfo.firstname} ${character.charinfo.lastname}`;
}

const UNITS: readonly [Intl.RelativeTimeFormatUnit, number][] = [
  ['year', 365 * 86400],
  ['month', 30 * 86400],
  ['week', 7 * 86400],
  ['day', 86400],
  ['hour', 3600],
  ['minute', 60],
];

const relative = new Intl.RelativeTimeFormat('en', { numeric: 'auto' });

export function lastPlayed(unixSeconds: number | undefined, now = Date.now()): string | null {
  if (unixSeconds == null) return null;

  const seconds = Math.round((unixSeconds * 1000 - now) / 1000);

  for (const [unit, size] of UNITS) {
    if (Math.abs(seconds) >= size) return relative.format(Math.round(seconds / size), unit);
  }

  return t('ui.character.just_now');
}
