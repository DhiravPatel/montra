import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './app/App';
import { getCurrentLanguage, loadNamespaces } from './shared/i18n/catalogs';
import './styles/index.css';

const container = document.getElementById('root');
if (!container) throw new Error('Missing #root element');

function render(root: HTMLElement) {
  createRoot(root).render(
    <StrictMode>
      <App />
    </StrictMode>,
  );
}

// English core messages ship with the app. Another interface language loads
// its core catalog first so the first paint is already translated (if that
// download fails, the page renders with the English fallback).
void loadNamespaces(getCurrentLanguage()).then(
  () => {
    render(container);
  },
  () => {
    render(container);
  },
);
