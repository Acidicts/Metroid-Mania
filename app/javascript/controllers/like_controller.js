import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    liked: Boolean,
    likeUrl: String,
    unlikeUrl: String,
    count: Number,
  }

  toggle() {
    const url = this.likedValue ? this.unlikeUrlValue : this.likeUrlValue

    fetch(url, {
      method: "POST",
      headers: {
        "X-CSRF-Token": this.csrfToken,
        "Accept": "text/vnd.turbo-stream.html",
      },
    })
      .then(response => response.text())
      .then(html => Turbo.renderStreamMessage(html))
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
