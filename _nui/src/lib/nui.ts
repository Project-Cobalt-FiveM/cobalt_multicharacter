import { toNuiMessage, type NuiCallbacks, type NuiMessage } from './types';

declare global {
  interface Window {
    GetParentResourceName?: () => string;
  }
}

export type CallbackName = keyof NuiCallbacks;
export type CallbackArgs<K extends CallbackName> = NuiCallbacks[K]['args'];
export type CallbackResult<K extends CallbackName> = NuiCallbacks[K]['result'];

export type MockHandlers = { [K in CallbackName]: (args: CallbackArgs<K>) => CallbackResult<K> };

let mockHandlers: MockHandlers | null = null;

export const inGame = 'GetParentResourceName' in window;

const resourceName = window.GetParentResourceName?.() ?? 'cobalt_multicharacter';

export function installMock(handlers: MockHandlers): void {
  mockHandlers = handlers;
}

export async function nui<K extends CallbackName>(name: K, args: CallbackArgs<K>): Promise<CallbackResult<K> | null> {
  if (mockHandlers) return mockHandlers[name](args);

  try {
    const response = await fetch(`https://${resourceName}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(args),
    });
    const body: CallbackResult<K> | null = await response.json();
    return body ?? null;
  } catch {
    return null;
  }
}

export function onNuiMessage(handler: (message: NuiMessage) => void): () => void {
  const listener = (event: MessageEvent<unknown>) => {
    const message = toNuiMessage(event.data);
    if (message) handler(message);
  };

  window.addEventListener('message', listener);
  return () => window.removeEventListener('message', listener);
}

export function dispatch(message: NuiMessage): void {
  window.dispatchEvent(new MessageEvent('message', { data: message }));
}
