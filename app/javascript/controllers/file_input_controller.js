import { Controller } from "@hotwired/stimulus"

// Usage: wrapper with data-controller="file-input"
// - input has data-file-input-target="input" and data-action "change->file-input#update"
// - span has data-file-input-target="filename"
// - optionally add <img data-file-input-target="preview"> and <button data-file-input-target="clear" data-action="click->file-input#clear"> to show preview and clear selection
export default class extends Controller {
  static targets = ["input", "filename", "preview", "clear"]

  connect() {
    if (this.hasInputTarget && this.inputTarget.files && this.inputTarget.files.length > 0) {
      this.update()
    }
  }

  update() {
    const file = this.inputTarget.files && this.inputTarget.files[0]
    this.filenameTarget.textContent = file ? file.name : "No file selected"

    if (file && this.hasPreviewTarget) {
      this._revokeLastUrl()
      const url = URL.createObjectURL(file)
      this._lastUrl = url
      this.previewTarget.src = url
      this.previewTarget.classList.remove('visually-hidden')
    } else if (this.hasPreviewTarget) {
      this.previewTarget.src = ''
      this.previewTarget.classList.add('visually-hidden')
    }

    if (this.hasClearTarget) {
      if (file) this.clearTarget.classList.remove('visually-hidden')
      else this.clearTarget.classList.add('visually-hidden')
    }
  }

  clear() {
    if (!this.hasInputTarget) return
    this.inputTarget.value = ''
    this.filenameTarget.textContent = 'No file selected'
    if (this.hasPreviewTarget) {
      this.previewTarget.src = ''
      this.previewTarget.classList.add('visually-hidden')
    }
    if (this.hasClearTarget) this.clearTarget.classList.add('visually-hidden')
    this._revokeLastUrl()
  }

  _revokeLastUrl() {
    if (this._lastUrl) {
      URL.revokeObjectURL(this._lastUrl)
      this._lastUrl = null
    }
  }
}