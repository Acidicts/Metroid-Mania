import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { taken: String }

  connect() {
    this.dropdown = this.element.querySelector('#hackatime-dropdown')
    this.selectedContainer = this.element.querySelector('#hackatime-selected')
    // Disable options that are marked taken (except ones already selected)
    this.takenNames = (this.takenValue || '').split(',').filter(Boolean)
    if (this.dropdown) {
      Array.from(this.dropdown.options).forEach(opt => {
        if (this.takenNames.includes(opt.value)) {
          opt.disabled = true
        }
      })
    }
  }

  add(event) {
    const val = this.dropdown.value
    if (!val || val === '') return
    // Prevent duplicates
    if (this.selectedContainer.querySelector(`[data-hackatime-value=\"${CSS.escape(val)}\"]`)) {
      this.dropdown.value = ''
      return
    }

    const chip = document.createElement('div')
    chip.className = 'hackatime-chip'
    chip.dataset.hackatimeValue = val

    const label = document.createElement('span')
    label.className = 'hackatime-label'
    label.textContent = val

    // Add seconds display when available
    const secondsAttr = this.dropdown.selectedOptions[0].dataset.seconds
    let secondsSpan = null
    if (secondsAttr && secondsAttr !== '') {
      secondsSpan = document.createElement('span')
      secondsSpan.className = 'hackatime-seconds'
      // Use format similar to server side (minutes/hours). Keep it simple: show minutes if < 3600 else hours+mins
      const secs = parseInt(secondsAttr, 10) || 0
      const hours = Math.floor(secs / 3600)
      const minutes = Math.floor((secs % 3600) / 60)
      // Match server-side format: "1h 30m"
      secondsSpan.textContent = `${hours}h ${minutes}m`
      chip.appendChild(secondsSpan)
    }

    const btn = document.createElement('button')
    btn.type = 'button'
    btn.className = 'hackatime-remove'
    btn.textContent = '✕'
    btn.addEventListener('click', (e) => this.remove(e))

    const hidden = document.createElement('input')
    hidden.type = 'hidden'
    hidden.name = 'project[hackatime_ids][]'
    hidden.value = val

    chip.appendChild(label)
    if (secondsSpan) chip.appendChild(secondsSpan)
    chip.appendChild(btn)
    chip.appendChild(hidden)

    this.selectedContainer.appendChild(chip)

    // Disable option in dropdown
    const option = Array.from(this.dropdown.options).find(o => o.value === val)
    if (option) option.disabled = true

    this.dropdown.value = ''
  }

  remove(event) {
    const btn = event.currentTarget || event.target
    const chip = btn.closest('.hackatime-chip')
    if (!chip) return
    const val = chip.dataset.hackatimeValue
    // Remove hidden input and chip
    chip.remove()
    // Re-enable dropdown option
    const option = Array.from(this.dropdown.options).find(o => o.value === val)
    if (option) option.disabled = false
  }
}
