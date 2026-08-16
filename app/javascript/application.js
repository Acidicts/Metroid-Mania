// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import '@hotwired/turbo-rails';
import 'controllers';

// Completely disable Turbo Drive to prevent frozen UI issues
// This disables automatic page navigation via Turbo but keeps Frames and Streams
import { Turbo } from '@hotwired/turbo-rails';
Turbo.session.drive = false;

console.log('Turbo Drive disabled - using traditional page loads to prevent frozen UI');

document.addEventListener('click', (event) => {
  const button = event.target.closest('[data-controller="admin-overlay"] [data-admin-overlay-target="button"]');
  if (!button) return;

  const container = button.closest('[data-controller="admin-overlay"]');
  const overlay = container && container.querySelector('[data-admin-overlay-target="overlay"]');
  if (!overlay) return;

  overlay.hidden = !overlay.hidden;
  overlay.classList.toggle('hidden', overlay.hidden);
  button.textContent = overlay.hidden ? 'Show DB Info' : 'Hide DB Info';
  button.setAttribute('aria-expanded', String(!overlay.hidden));
});

function initThemedFormValidationWarnings() {
  if (window.__themedValidationWarningsBound) return;
  window.__themedValidationWarningsBound = true;

  let warningCount = 0;
  const warningTimers = new WeakMap();

  function isValidatableField(field) {
    return (
      field instanceof HTMLInputElement ||
      field instanceof HTMLTextAreaElement ||
      field instanceof HTMLSelectElement
    );
  }

  function nextWarningId() {
    warningCount += 1;
    return `validation-warning-${warningCount}`;
  }

  function addDescribedByToken(field, id) {
    const current = (field.getAttribute('aria-describedby') || '').split(/\s+/).filter(Boolean);
    if (!current.includes(id)) {
      current.push(id);
      field.setAttribute('aria-describedby', current.join(' '));
    }
  }

  function removeDescribedByToken(field, id) {
    const next = (field.getAttribute('aria-describedby') || '')
      .split(/\s+/)
      .filter((token) => token && token !== id);
    if (next.length > 0) {
      field.setAttribute('aria-describedby', next.join(' '));
    } else {
      field.removeAttribute('aria-describedby');
    }
  }

  function createWarningElement(field) {
    const warning = document.createElement('p');
    warning.className = 'field-validation-warning';
    warning.dataset.validationWarning = 'true';
    warning.id = nextWarningId();
    warning.setAttribute('role', 'alert');
    warning.setAttribute('aria-live', 'polite');

    field.insertAdjacentElement('afterend', warning);
    return warning;
  }

  function getWarningElement(field) {
    const sibling = field.nextElementSibling;
    if (sibling && sibling.dataset.validationWarning === 'true') {
      return sibling;
    }
    return null;
  }

  function showFieldWarning(field, message) {
    const existingWarning = getWarningElement(field);
    if (existingWarning) {
      clearTimeout(warningTimers.get(field));
      existingWarning.classList.remove('fade-out');
    }

    const text = String(message || 'Please fill in this field.').trim();
    const warning = existingWarning || createWarningElement(field);

    warning.textContent = text;
    field.classList.add('field-invalid');
    field.dataset.themedFieldInvalid = 'true';
    field.setAttribute('aria-invalid', 'true');
    addDescribedByToken(field, warning.id);

    const timer = setTimeout(() => {
      warning.classList.add('fade-out');
      setTimeout(() => clearFieldWarning(field), 400);
    }, 3000);
    warningTimers.set(field, timer);
  }

  function clearFieldWarning(field) {
    clearTimeout(warningTimers.get(field));
    warningTimers.delete(field);

    const warning = getWarningElement(field);
    if (warning) {
      warning.classList.remove('fade-out');
      removeDescribedByToken(field, warning.id);
      warning.remove();
    }

    field.classList.remove('field-invalid');
    if (field.dataset.themedFieldInvalid === 'true') {
      field.removeAttribute('aria-invalid');
      delete field.dataset.themedFieldInvalid;
    }
  }

  document.addEventListener(
    'invalid',
    (event) => {
      const field = event.target;
      if (!isValidatableField(field)) return;
      if (field.form && field.form.dataset.nativeValidation === 'true') return;

      event.preventDefault();
      showFieldWarning(field, field.validationMessage);
    },
    true
  );

  document.addEventListener(
    'input',
    (event) => {
      const field = event.target;
      if (!isValidatableField(field)) return;

      if (field.validity.valid) {
        clearFieldWarning(field);
      }
    },
    true
  );

  document.addEventListener(
    'change',
    (event) => {
      const field = event.target;
      if (!isValidatableField(field)) return;

      if (field.validity.valid) {
        clearFieldWarning(field);
      }
    },
    true
  );
}

initThemedFormValidationWarnings();

// Restore data-confirm behavior on links (Turbo Drive is disabled,
// so Turbo only handles confirm on form submissions, not link clicks).
document.addEventListener('click', (event) => {
  const link = event.target.closest('a[data-confirm]');
  if (!link) return;

  const message = link.getAttribute('data-confirm');
  if (!confirm(message)) {
    event.preventDefault();
    event.stopImmediatePropagation();
  }
}, true);
