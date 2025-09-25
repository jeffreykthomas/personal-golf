import { Controller } from '@hotwired/stimulus';

// data-controller="upload"
// Targets: input (file), zone (drop area), overlay, viewport, cropImage, zoom
export default class extends Controller {
  static targets = [
    'input',
    'zone',
    'overlay',
    'viewport',
    'cropImage',
    'zoom',
    'controls',
    'actions',
    'loading',
  ];

  static values = {
    aspect: { type: Number, default: 3 / 4 },
  };

  connect() {
    // Cropping state
    this._activeFile = null;
    this._imageNaturalWidth = 0;
    this._imageNaturalHeight = 0;
    this._dragging = false;
    this._startX = 0;
    this._startY = 0;
    this._offsetX = 0; // px offset relative to viewport center
    this._offsetY = 0;
    this._zoom = 1.0; // user zoom factor >= 1

    // Bind handlers to preserve 'this'
    this._onPointerDown = this.onPointerDown.bind(this);
    this._onPointerMove = this.onPointerMove.bind(this);
    this._onPointerUp = this.onPointerUp.bind(this);
    this._onResize = this.onWindowResize.bind(this);
    this._onSubmitEnd = this.onSubmitEnd.bind(this);
    this.element.addEventListener('turbo:submit-end', this._onSubmitEnd);
  }

  disconnect() {
    this.element.removeEventListener('turbo:submit-end', this._onSubmitEnd);
  }

  pick() {
    if (this.hasInputTarget) this.inputTarget.click();
  }

  // When file input changes, open cropper instead of immediate submit
  changed() {
    if (this.inputTarget.files && this.inputTarget.files.length > 0) {
      const file = this.inputTarget.files[0];
      // Client-side 10MB limit for videos (and images for good measure)
      const maxBytes = 10 * 1024 * 1024;
      if (file.size && file.size > maxBytes) {
        alert('File must be 10MB or smaller.');
        // Reset input so user can pick another
        this.inputTarget.value = '';
        return;
      }
      if (file.type?.startsWith('image/')) {
        this.openCropper(file);
      } else if (file.type?.startsWith('video/')) {
        // For videos, skip cropper and submit directly with an uploading indicator
        this.showOverlay();
        this.showUploading();
        this.element.requestSubmit();
      } else {
        // Unknown type, just submit and let server validate
        this.element.requestSubmit();
      }
    }
  }

  dragOver(event) {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'copy';
    this.zoneTarget.classList.add('ring-2', 'ring-[#00dc82]');
  }

  dragLeave(event) {
    event.preventDefault();
    this.zoneTarget.classList.remove('ring-2', 'ring-[#00dc82]');
  }

  drop(event) {
    event.preventDefault();
    this.zoneTarget.classList.remove('ring-2', 'ring-[#00dc82]');
    const files = event.dataTransfer.files;
    if (files && files.length > 0 && this.hasInputTarget) {
      const file = files[0];
      const maxBytes = 10 * 1024 * 1024;
      if (file.size && file.size > maxBytes) {
        alert('File must be 10MB or smaller.');
        return;
      }
      // Also reflect in input for form submission after crop
      const dt = new DataTransfer();
      dt.items.add(file);
      this.inputTarget.files = dt.files;
      if (file.type?.startsWith('image/')) {
        this.openCropper(file);
      } else if (file.type?.startsWith('video/')) {
        this.showOverlay();
        this.showUploading();
        this.element.requestSubmit();
      } else {
        this.element.requestSubmit();
      }
    }
  }

  // Overlay controls
  setAspect(event) {
    const aspectStr = event?.params?.value || event?.target?.dataset?.aspect;
    let ratio = this.aspectValue;
    if (aspectStr) {
      if (aspectStr.includes(':')) {
        const [a, b] = aspectStr.split(':').map((n) => parseFloat(n));
        if (a > 0 && b > 0) ratio = a / b;
      } else {
        const num = parseFloat(aspectStr);
        if (!Number.isNaN(num) && num > 0) ratio = num;
      }
    }
    this.aspectValue = ratio;
    this.applyViewportAspect();
    this.fitImageToViewport();
    this.renderTransform();
  }

  zoomChanged(event) {
    const val = parseFloat(event.target.value);
    this._zoom = Math.max(1, Math.min(3, val || 1));
    this.fitImageToViewport(false); // keep offsets, just clamp
    this.renderTransform();
  }

  cancelCrop() {
    this.hideOverlay();
    // If user cancels, clear file input selection
    this.inputTarget.value = '';
    this._activeFile = null;
  }

  async confirmCrop() {
    if (!this._activeFile || !this.hasViewportTarget || !this.hasCropImageTarget) return;

    const { cropLeft, cropTop, cropWidth, cropHeight } = this.computeCropRect();
    if (cropWidth <= 0 || cropHeight <= 0) {
      this.hideOverlay();
      return;
    }

    // Create canvas at cropped size (cap longest edge to 2000px to control size)
    const maxEdge = 2000;
    const scaleDown = Math.min(1, maxEdge / Math.max(cropWidth, cropHeight));
    const outW = Math.round(cropWidth * scaleDown);
    const outH = Math.round(cropHeight * scaleDown);

    // Use the same bitmap that we displayed to avoid decoding differences
    const bitmap = await createImageBitmap(this._activeFile);
    const canvas = document.createElement('canvas');
    canvas.width = outW;
    canvas.height = outH;
    const ctx = canvas.getContext('2d', { willReadFrequently: false });
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(bitmap, cropLeft, cropTop, cropWidth, cropHeight, 0, 0, outW, outH);

    const outputType =
      this._activeFile.type && this._activeFile.type.startsWith('image/')
        ? this._activeFile.type
        : 'image/jpeg';
    const blob = await new Promise((resolve) => canvas.toBlob(resolve, outputType, 0.92));
    const filename = this._activeFile.name?.replace(/\.(png|jpg|jpeg|gif|webp)$/i, '') || 'layout';
    const outFile = new File([blob], `${filename}_cropped.${this.extensionForType(outputType)}`, {
      type: outputType,
    });

    const dt = new DataTransfer();
    dt.items.add(outFile);
    this.inputTarget.files = dt.files;

    this.showUploading();
    this.element.requestSubmit();
  }

  // Internal helpers
  openCropper(file) {
    if (!file || !file.type?.startsWith('image/')) return;
    this._activeFile = file;
    const reader = new FileReader();
    reader.onload = () => {
      this.cropImageTarget.src = reader.result;
      // Wait for img to render and load its natural sizes
      this.cropImageTarget.onload = () => {
        this._imageNaturalWidth = this.cropImageTarget.naturalWidth;
        this._imageNaturalHeight = this.cropImageTarget.naturalHeight;
        this._offsetX = 0;
        this._offsetY = 0;
        this._zoom = 1.0;
        // Ensure overlay is visible before measuring sizes
        this.showOverlay();
        this.showCropUI();
        // Initialize zoom slider
        if (this.hasZoomTarget) this.zoomTarget.value = '1';
        // Defer layout until next frame so DOM has painted, then one more frame
        requestAnimationFrame(() => {
          this.applyViewportAspect();
          this.fitImageToViewport();
          this.renderTransform();
          // Force a layout flush and then reveal so first visible frame is filled
          this.viewportTarget.getBoundingClientRect();
          this.revealOverlay();
        });
        // Pointer events for dragging
        this.viewportTarget.addEventListener('pointerdown', this._onPointerDown);
        window.addEventListener('pointermove', this._onPointerMove);
        window.addEventListener('pointerup', this._onPointerUp);
      };
    };
    reader.readAsDataURL(file);
  }

  showOverlay() {
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove('hidden');
      // Keep it in layout for accurate measurements but make it invisible
      this.overlayTarget.style.visibility = 'hidden';
      this.overlayTarget.style.opacity = '0';
    }
    window.addEventListener('resize', this._onResize);
  }

  revealOverlay() {
    if (this.hasOverlayTarget) {
      this.overlayTarget.style.visibility = 'visible';
      this.overlayTarget.style.opacity = '';
    }
  }

  showCropUI() {
    if (this.hasControlsTarget) this.controlsTarget.classList.remove('hidden');
    if (this.hasActionsTarget) this.actionsTarget.classList.remove('hidden');
    if (this.hasViewportTarget) this.viewportTarget.classList.remove('hidden');
    if (this.hasLoadingTarget) this.loadingTarget.classList.add('hidden');
  }

  showUploading() {
    if (this.hasControlsTarget) this.controlsTarget.classList.add('hidden');
    if (this.hasActionsTarget) this.actionsTarget.classList.add('hidden');
    if (this.hasViewportTarget) this.viewportTarget.classList.add('hidden');
    if (this.hasLoadingTarget) this.loadingTarget.classList.remove('hidden');
  }

  hideOverlay() {
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add('hidden');
    }
    // Cleanup listeners
    if (this.hasViewportTarget) {
      this.viewportTarget.removeEventListener('pointerdown', this._onPointerDown);
    }
    window.removeEventListener('pointermove', this._onPointerMove);
    window.removeEventListener('pointerup', this._onPointerUp);
    window.removeEventListener('resize', this._onResize);
  }

  applyViewportAspect() {
    if (!this.hasViewportTarget) return;
    // Compute viewport size so that it fits within available width & height (<= 100vh)
    const viewportEl = this.viewportTarget;
    const containerEl = viewportEl.parentElement || viewportEl;
    const maxWidth = containerEl.clientWidth || 640;
    // Available height: overlay height minus controls/actions heights and margins
    const overlayH = this.hasOverlayTarget ? this.overlayTarget.clientHeight : window.innerHeight;
    const controlsH = this.hasControlsTarget ? this.controlsTarget.offsetHeight : 0;
    const actionsH = this.hasActionsTarget ? this.actionsTarget.offsetHeight : 0;
    const verticalPadding = 32; // ~p-4 top+bottom inside overlay
    const availableH = Math.max(100, overlayH - controlsH - actionsH - verticalPadding);

    // First try full width based on aspect
    const heightFromWidth = Math.round(maxWidth / this.aspectValue);
    let targetW = maxWidth;
    let targetH = heightFromWidth;
    if (heightFromWidth > availableH) {
      // Too tall; cap by height and compute width
      targetH = availableH;
      targetW = Math.round(targetH * this.aspectValue);
    }
    viewportEl.style.width = `${targetW}px`;
    viewportEl.style.height = `${targetH}px`;
  }

  fitImageToViewport(resetOffsets = true) {
    if (!this.hasViewportTarget || !this.hasCropImageTarget) return;
    const Vw = this.viewportTarget.clientWidth;
    const Vh = this.viewportTarget.clientHeight;
    const w0 = this._imageNaturalWidth || 1;
    const h0 = this._imageNaturalHeight || 1;
    console.log('Vw', Vw);
    console.log('Vh', Vh);
    console.log('w0', w0);
    console.log('h0', h0);
    // Base scale ensures image covers the viewport fully (fill)
    const baseScale = Math.max(Vw / w0, Vh / h0);
    console.log('baseScale', baseScale);
    console.log('this._zoom', this._zoom);
    this._scale = baseScale * this._zoom;
    if (resetOffsets) {
      this._offsetX = 0;
      this._offsetY = 0;
    }
    // Clamp offsets to avoid empty space; when scale exceeds necessary fill, keep image bounded by viewport
    const halfW = (w0 * this._scale) / 2;
    const halfH = (h0 * this._scale) / 2;
    const maxX = Math.max(0, halfW - Vw / 2);
    const maxY = Math.max(0, halfH - Vh / 2);
    this._offsetX = Math.max(-maxX, Math.min(maxX, this._offsetX));
    this._offsetY = Math.max(-maxY, Math.min(maxY, this._offsetY));
  }

  renderTransform() {
    if (!this.hasCropImageTarget || !this.hasViewportTarget) return;
    // Center-based transform
    const translate = `translate(calc(50% + ${this._offsetX}px), calc(50% + ${this._offsetY}px))`;
    const scale = `scale(${this._scale})`;
    this.cropImageTarget.style.transformOrigin = '0 0';
    this.cropImageTarget.style.transform = `${translate} translate(-50%, -50%) ${scale}`;
    console.log('renderTransform');
    console.log('translate', translate);
    console.log('scale', scale);
    console.log('this._offsetX', this._offsetX);
    console.log('this._offsetY', this._offsetY);
    console.log('this._scale', this._scale);
  }

  onWindowResize() {
    // Recompute layout when viewport changes
    this.applyViewportAspect();
    this.fitImageToViewport(false);
    this.renderTransform();
  }

  onSubmitEnd() {
    this.hideOverlay();
  }

  onPointerDown(e) {
    if (!this.hasViewportTarget) return;
    this._dragging = true;
    this.viewportTarget.setPointerCapture(e.pointerId);
    this._startX = e.clientX;
    this._startY = e.clientY;
  }

  onPointerMove(e) {
    if (!this._dragging) return;
    const dx = e.clientX - this._startX;
    const dy = e.clientY - this._startY;
    this._startX = e.clientX;
    this._startY = e.clientY;
    this._offsetX += dx;
    this._offsetY += dy;
    this.fitImageToViewport(false);
    this.renderTransform();
  }

  onPointerUp(e) {
    if (!this._dragging) return;
    this._dragging = false;
    try {
      this.viewportTarget.releasePointerCapture(e.pointerId);
    } catch (_) {}
  }

  computeCropRect() {
    // Robust mapping: use actual painted sizes via DOM rects to avoid math drift
    const imgRect = this.cropImageTarget.getBoundingClientRect();
    const vpRect = this.viewportTarget.getBoundingClientRect();
    const w0 = this._imageNaturalWidth;
    const h0 = this._imageNaturalHeight;

    if (imgRect.width === 0 || imgRect.height === 0 || vpRect.width === 0 || vpRect.height === 0) {
      // Fallback to scale-based mapping if something is hidden
      const Vw = this.viewportTarget.clientWidth;
      const Vh = this.viewportTarget.clientHeight;
      const s = this._scale || 1;
      const dx = this._offsetX || 0;
      const dy = this._offsetY || 0;
      const u0 = w0 / 2 + (0 - Vw / 2 - dx) / s;
      const v0 = h0 / 2 + (0 - Vh / 2 - dy) / s;
      const u1 = w0 / 2 + (Vw - Vw / 2 - dx) / s;
      const v1 = h0 / 2 + (Vh - Vh / 2 - dy) / s;
      const left = Math.max(0, Math.min(w0, u0));
      const top = Math.max(0, Math.min(h0, v0));
      const right = Math.max(0, Math.min(w0, u1));
      const bottom = Math.max(0, Math.min(h0, v1));
      const cropWidth = Math.max(0, Math.round(right - left));
      const cropHeight = Math.max(0, Math.round(bottom - top));
      return { cropLeft: Math.round(left), cropTop: Math.round(top), cropWidth, cropHeight };
    }

    // CSS pixels to image pixels scale (uniform scale assumed)
    const cssToImgX = w0 / imgRect.width;
    const cssToImgY = h0 / imgRect.height;
    // Top-left of viewport relative to image top-left in CSS px
    const relLeftCss = vpRect.left - imgRect.left;
    const relTopCss = vpRect.top - imgRect.top;
    // Convert to image pixels
    let left = Math.round(relLeftCss * cssToImgX);
    let top = Math.round(relTopCss * cssToImgY);
    let cropWidth = Math.round(vpRect.width * cssToImgX);
    let cropHeight = Math.round(vpRect.height * cssToImgY);

    // Clamp to image bounds
    left = Math.max(0, Math.min(w0 - 1, left));
    top = Math.max(0, Math.min(h0 - 1, top));
    if (left + cropWidth > w0) cropWidth = w0 - left;
    if (top + cropHeight > h0) cropHeight = h0 - top;

    return { cropLeft: left, cropTop: top, cropWidth, cropHeight };
  }

  extensionForType(type) {
    if (type.includes('png')) return 'png';
    if (type.includes('webp')) return 'webp';
    return 'jpg';
  }
}
