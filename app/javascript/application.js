// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import '@hotwired/turbo-rails';
import 'controllers';

// Completely disable Turbo Drive to prevent frozen UI issues
// This disables automatic page navigation via Turbo but keeps Frames and Streams
import { Turbo } from '@hotwired/turbo-rails';
Turbo.session.drive = false;

console.log('Turbo Drive disabled - using traditional page loads to prevent frozen UI');

function initThemedFormValidationWarnings() {
  if (window.__themedValidationWarningsBound) return;
  window.__themedValidationWarningsBound = true;

  let warningCount = 0;

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
    const text = String(message || 'Please fill in this field.').trim();
    const warning = getWarningElement(field) || createWarningElement(field);

    warning.textContent = text;
    field.classList.add('field-invalid');
    field.dataset.themedFieldInvalid = 'true';
    field.setAttribute('aria-invalid', 'true');
    addDescribedByToken(field, warning.id);
  }

  function clearFieldWarning(field) {
    const warning = getWarningElement(field);
    if (warning) {
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
