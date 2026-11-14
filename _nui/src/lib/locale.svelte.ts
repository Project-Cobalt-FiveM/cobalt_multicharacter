import type { Locales } from './types';

let dict: Locales = $state.raw({});

export function t(key: string, ...args: (string | number)[]): string {
  const template = dict[key];
  if (template == null) return key;

  let index = 0;
  return template.replace(/%[sd]/g, (placeholder) => {
    const value = args[index++];
    return value == null ? placeholder : String(value);
  });
}

export function setLocales(locales: Locales): void {
  dict = locales;
}
