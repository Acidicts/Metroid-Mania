import { Controller } from '@hotwired/stimulus';

// Usage: wrapper with data-controller="file-input"
// - input has data-file-input-target="input" and data-action "change->file-input#update"
// - span has data-file-input-target="filename"
// - optionally add <img data-file-input-target="preview"> and <button data-file-input-target="clear" data-action="click->file-input#clear"> to show preview and clear selection
export default class extends Controller {
  static targets = ['input', 'filename', 'preview', 'clear', 'dropzone', 'text'];

  connect() {
    if (this.hasInputTarget && this.inputTarget.files && this.inputTarget.files.length > 0) {
      this.update();
    }

    if (this.hasDropzoneTarget) {
      this._bindDropzoneEvents();
    }
  }

  async update() {
    let file = this.inputTarget.files && this.inputTarget.files[0];
    if (file) {
      const converted = await this._maybeConvertFile(file);
      if (converted !== file) {
        const dataTransfer = new DataTransfer();
        dataTransfer.items.add(converted);
        this.inputTarget.files = dataTransfer.files;
        file = converted;
      }
    }

    if (file && this.hasPreviewTarget) {
      this._revokeLastUrl();
      const url = URL.createObjectURL(file);
      this._lastUrl = url;
      this.previewTarget.src = url;
      this.previewTarget.style.display = 'block';
      if (this.hasTextTarget) {
        this.textTarget.style.display = 'none';
      }
    } else if (this.hasPreviewTarget) {
      this.previewTarget.src = '';
      this.previewTarget.style.display = 'none';
      if (this.hasTextTarget) {
        this.textTarget.style.display = 'flex';
      }
    }

    if (this.hasClearTarget) {
      if (file) this.clearTarget.classList.remove('visually-hidden');
      else this.clearTarget.classList.add('visually-hidden');
    }
  }

  disconnect() {
    if (this.hasDropzoneTarget) {
      this._unbindDropzoneEvents();
    }
  }

  dragEnter(event) {
    event.preventDefault();
    event.stopPropagation();
    this._setDropzoneActive(true);
  }

  dragOver(event) {
    event.preventDefault();
    event.stopPropagation();
    event.dataTransfer.dropEffect = 'copy';
    this._setDropzoneActive(true);
  }

  dragLeave(event) {
    event.preventDefault();
    event.stopPropagation();
    this._setDropzoneActive(false);
  }

  drop(event) {
    event.preventDefault();
    event.stopPropagation();
    this._setDropzoneActive(false);

    if (!event.dataTransfer || !event.dataTransfer.files || event.dataTransfer.files.length === 0) {
      return;
    }

    this._setFiles(event.dataTransfer.files);
  }

  paste(event) {
    if (!this.element.contains(document.activeElement)) {
      return;
    }

    if (!event.clipboardData || !event.clipboardData.items) {
      return;
    }

    const imageItem = Array.from(event.clipboardData.items).find(
      (item) => item.kind === 'file' && item.type.startsWith('image/')
    );
    if (!imageItem) {
      return;
    }

    const file = imageItem.getAsFile();
    if (!file) {
      return;
    }

    event.preventDefault();
    this._setFiles([file]);
  }

  clear() {
    if (!this.hasInputTarget) return;
    this.inputTarget.value = '';
    if (this.hasPreviewTarget) {
      this.previewTarget.src = '';
      this.previewTarget.style.display = 'none';
    }
    if (this.hasTextTarget) {
      this.textTarget.style.display = 'flex';
    }
    if (this.hasClearTarget) this.clearTarget.classList.add('visually-hidden');
    this._revokeLastUrl();
  }

  _bindDropzoneEvents() {
    this._onDragEnter = this.dragEnter.bind(this);
    this._onDragOver = this.dragOver.bind(this);
    this._onDragLeave = this.dragLeave.bind(this);
    this._onDrop = this.drop.bind(this);
    this._onPaste = this.paste.bind(this);

    this.dropzoneTarget.addEventListener('dragenter', this._onDragEnter);
    this.dropzoneTarget.addEventListener('dragover', this._onDragOver);
    this.dropzoneTarget.addEventListener('dragleave', this._onDragLeave);
    this.dropzoneTarget.addEventListener('drop', this._onDrop);
    document.addEventListener('paste', this._onPaste);
  }

  _unbindDropzoneEvents() {
    this.dropzoneTarget.removeEventListener('dragenter', this._onDragEnter);
    this.dropzoneTarget.removeEventListener('dragover', this._onDragOver);
    this.dropzoneTarget.removeEventListener('dragleave', this._onDragLeave);
    this.dropzoneTarget.removeEventListener('drop', this._onDrop);
    document.removeEventListener('paste', this._onPaste);
  }

  _setDropzoneActive(active) {
    if (!this.hasDropzoneTarget) return;
    this.dropzoneTarget.classList.toggle('file-input-dropzone--active', active);
  }

  _setFiles(files) {
    if (!this.hasInputTarget) return;
    const firstFile = files[0];
    if (!firstFile) return;

    const dataTransfer = new DataTransfer();
    dataTransfer.items.add(firstFile);
    this.inputTarget.files = dataTransfer.files;
    this.update();
  }

  async _maybeConvertFile(file) {
    if (!file.type.startsWith('image/') || file.type === 'image/jpeg') {
      return file;
    }

    try {
      return await this._convertImageToJpeg(file);
    } catch (error) {
      console.warn('Image conversion failed, uploading original file instead.', error);
      return file;
    }
  }

  _convertImageToJpeg(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onerror = () => reject(new Error('Failed to read file for conversion'));
      reader.onload = () => {
        const image = new Image();
        image.onerror = () => reject(new Error('Failed to load image for conversion'));
        image.onload = async () => {
          const canvas = document.createElement('canvas');
          canvas.width = image.naturalWidth || image.width || 1;
          canvas.height = image.naturalHeight || image.height || 1;
          const ctx = canvas.getContext('2d');
          if (!ctx) {
            reject(new Error('Canvas 2D context unavailable'));
            return;
          }
          ctx.fillStyle = '#ffffff';
          ctx.fillRect(0, 0, canvas.width, canvas.height);
          ctx.drawImage(image, 0, 0, canvas.width, canvas.height);

          canvas.toBlob(
            (blob) => {
              if (!blob) {
                reject(new Error('JPEG conversion returned empty blob'));
                return;
              }
              const baseName = file.name.replace(/\.[^/.]+$/, '');
              const jpegFile = new File([blob], `${baseName}.jpg`, { type: 'image/jpeg' });
              resolve(jpegFile);
            },
            'image/jpeg',
            0.92
          );
        };
        image.src = reader.result;
      };
      reader.readAsDataURL(file);
    });
  }

  _revokeLastUrl() {
    if (this._lastUrl) {
      URL.revokeObjectURL(this._lastUrl);
      this._lastUrl = null;
    }
  }
}
