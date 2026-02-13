import { Controller } from "@hotwired/stimulus"

// Validates repository_url/readme_url on the project form.
// - Blocks submit only on explicit HTTP 404 responses.
// - Shows inline status messages and is defensive (no uncaught exceptions).
// Implementation is defensive to avoid throwing and interfering with other site JS.
export default class extends Controller {
  static targets = ["repo", "readme", "repoStatus", "readmeStatus"]

  connect() {
    try {
      this._onRepoInput = () => { this._clearStatus(this.repoStatusTarget) }
      this._onRepoBlur = () => { this.checkRepositoryInput().catch(() => {}) }
      this._onReadmeInput = () => { this._clearStatus(this.readmeStatusTarget) }
      this._onReadmeBlur = () => { this.checkReadmeInput().catch(() => {}) }
      this._onSubmit = async (e) => await this._handleSubmit(e)

      if (this.hasRepoTarget) {
        this.repoTarget.addEventListener('input', this._onRepoInput)
        this.repoTarget.addEventListener('blur', this._onRepoBlur)
      }
      if (this.hasReadmeTarget) {
        this.readmeTarget.addEventListener('input', this._onReadmeInput)
        this.readmeTarget.addEventListener('blur', this._onReadmeBlur)
      }

      // the controller root is the form element (we set data-controller on the form)
      this.element.addEventListener('submit', this._onSubmit)
    } catch (err) {
      // swallow to avoid breaking other JS on the page
      console.warn('project-url-validator connect error', err)
    }
  }

  disconnect() {
    try {
      if (this.hasRepoTarget) {
        this.repoTarget.removeEventListener('input', this._onRepoInput)
        this.repoTarget.removeEventListener('blur', this._onRepoBlur)
      }
      if (this.hasReadmeTarget) {
        this.readmeTarget.removeEventListener('input', this._onReadmeInput)
        this.readmeTarget.removeEventListener('blur', this._onReadmeBlur)
      }
      this.element.removeEventListener('submit', this._onSubmit)
    } catch (err) {
      // ignore
    }
  }

  // ----- helpers -----
  _setStatus(target, text, cls) {
    if (!target) return
    target.textContent = text || ''
    target.className = 'input-status ' + (cls || '')
  }

  _clearStatus(target) {
    if (!target) return
    target.textContent = ''
    target.className = 'input-status'
  }

  // simpler, single-line implementation to avoid accidental newline breaks
  _isGitSsh(str) { return /^git@github\.com:[^\/\s@]+\/[^\/\s@]+(?:\.git)?$/i.test(String(str || '')) }
  _isProbablyUrl(str) { try { new URL(String(str || '')); return true } catch(e) { return false } }

  _parseGithubRepo(url) {
    if (!url) return null
    const match = String(url).match(/(?:github\.com[:\/])([^\/\s@]+)\/([^\/\s@]+)(?:\.git)?(?:[\/\#?].*)?/i)
    if (!match) {
      if (this._isGitSsh(url)) {
        const sshMatch = String(url).match(/^git@github\.com:([^\/\s@]+)\/([^\/\s@]+)(?:\.git)?$/i)
        if (sshMatch) return { owner: sshMatch[1], repo: sshMatch[2] }
      }
      return null
    }
    const owner = match[1]
    const repoName = match[2].replace(/\.git$/i, '')
    const branchMatch = String(url).match(/\/(?:tree|blob)\/([^\/\s\/]+)/i)
    return { owner, repo: repoName, branch: branchMatch ? branchMatch[1] : null }
  }

  async _fetchResponse(url) {
    if (!window.fetch) return null
    try { const r = await fetch(url, { method: 'HEAD' }); return r } catch (e) {
      try { const r2 = await fetch(url, { method: 'GET' }); return r2 } catch (e2) { return null }
    }
  }

  // ----- validation logic (only 404 blocks) -----
  async checkRepositoryInput() {
    try {
      const v = (this.hasRepoTarget ? (this.repoTarget.value || '').trim() : '')
      if (!v) { this._setStatus(this.repoStatusTarget, 'Repository URL is empty — optional but recommended.', ''); return true }

      const parsed = this._parseGithubRepo(v)
      if (!parsed) {
        if (this._isProbablyUrl(v)) {
          this._setStatus(this.repoStatusTarget, "Not a recognized GitHub repository URL — we won't verify it.", 'checking')
          return true
        }
        this._setStatus(this.repoStatusTarget, 'Looks like plain text (not a URL). Accepted but not verified.', 'checking')
        return true
      }

      this._setStatus(this.repoStatusTarget, 'Checking GitHub for README...', 'checking')
      const candidateUrls = parsed.branch ?
        [`https://raw.githubusercontent.com/${parsed.owner}/${parsed.repo}/${encodeURIComponent(parsed.branch)}/README.md`] :
        [`https://raw.githubusercontent.com/${parsed.owner}/${parsed.repo}/main/README.md`, `https://raw.githubusercontent.com/${parsed.owner}/${parsed.repo}/master/README.md`]

      let saw404 = false
      for (const u of candidateUrls) {
        const res = await this._fetchResponse(u)
        if (res && res.ok) {
          this._setStatus(this.repoStatusTarget, 'Found README on GitHub — looks good ✅', 'success')
          if (this.hasReadmeTarget && !this.readmeTarget.value.trim()) this.readmeTarget.value = u
          return true
        }
        if (res && res.status === 404) saw404 = true
      }

      if (saw404) {
        this._setStatus(this.repoStatusTarget, 'README returned 404 on GitHub — submission blocked.', 'error')
        return false
      }

      // inconclusive (network/CORS/403/etc) — warn but allow
      this._setStatus(this.repoStatusTarget, 'Could not verify README on GitHub (network/CORS or non-200). Submission allowed.', 'checking')
      return true
    } catch (err) {
      console.warn('checkRepositoryInput failed', err)
      return true
    }
  }

  async checkReadmeInput() {
    try {
      const v = (this.hasReadmeTarget ? (this.readmeTarget.value || '').trim() : '')
      if (!v) { this._setStatus(this.readmeStatusTarget, 'No README URL provided.', ''); return true }
      if (!this._isProbablyUrl(v)) {
        this._setStatus(this.readmeStatusTarget, 'Readme must be a valid URL (include https://).', 'error')
        return false
      }

      this._setStatus(this.readmeStatusTarget, 'Checking readme URL...', 'checking')
      const res = await this._fetchResponse(v)
      if (!res) {
        this._setStatus(this.readmeStatusTarget, 'Could not verify README URL (network/CORS). Submission allowed.', 'checking')
        return true
      }

      if (res.status === 404) {
        this._setStatus(this.readmeStatusTarget, 'Readme URL returned 404 (not found) — submission blocked.', 'error')
        return false
      }

      if (!res.ok) {
        this._setStatus(this.readmeStatusTarget, `Readme returned status ${res.status} — submission allowed.`, 'checking')
        return true
      }

      // check content-type on GET but do not block on odd types
      try {
        const getRes = await fetch(v, { method: 'GET' })
        const ct = getRes.headers.get('content-type') || ''
        if (!ct.includes('text') && !ct.includes('markdown')) {
          this._setStatus(this.readmeStatusTarget, `Readme reachable but content-type looks unusual (${ct}) — submission allowed.`, 'checking')
          return true
        }
      } catch (err) {
        // ignore GET failures when HEAD succeeded
      }

      this._setStatus(this.readmeStatusTarget, 'README reachable and looks valid ✅', 'success')
      return true
    } catch (err) {
      console.warn('checkReadmeInput failed', err)
      return true
    }
  }

  async _handleSubmit(e) {
    try {
      const repoLooksUrl = this.hasRepoTarget && (this._isProbablyUrl((this.repoTarget.value||'').trim()) || this._isGitSsh((this.repoTarget.value||'').trim()))
      const readmeLooksUrl = this.hasReadmeTarget && this._isProbablyUrl((this.readmeTarget.value||'').trim())
      let ok = true
      if (repoLooksUrl) ok = await this.checkRepositoryInput() && ok
      if (readmeLooksUrl) ok = await this.checkReadmeInput() && ok
      if (!ok) {
        e.preventDefault()
        const firstInvalid = this.element.querySelector('[aria-invalid="true"]')
        if (firstInvalid) firstInvalid.focus()
      }
    } catch (err) {
      // If our validation errors, allow the submit to proceed rather than block whole form
      console.warn('project-url-validator submit handler error', err)
    }
  }
}
