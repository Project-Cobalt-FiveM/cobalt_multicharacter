import { mount } from 'svelte';
import './app.css';
import App from './App.svelte';
import { inGame } from './lib/nui';

const target = document.getElementById('app');

if (target) {
  mount(App, { target });
  if (import.meta.env.DEV && !inGame) void import('./lib/mock');
}
