// app/javascript/controllers/image_swiper_controller.js
import { Controller } from '@hotwired/stimulus';

// Handles left/right swipe and button navigation for a list of images
export default class extends Controller {
  static targets = [
    'image', // <img>
    'indexLabel', // span for index display
    'container', // wrapper for gesture area
  ];

  static values = {
    images: Array, // array of URLs
    index: { type: Number, default: 0 },
    threshold: { type: Number, default: 50 }, // px to trigger swipe
  };

  connect() {
    this.startX = 0;
    this.currentX = 0;
    this.isSwiping = false;

    // Render initial image
    this.showIndex(this.indexValue);

    // Keyboard support
    this.keyHandler = (e) => {
      if (e.key === 'ArrowRight') this.next();
      if (e.key === 'ArrowLeft') this.prev();
    };
    window.addEventListener('keydown', this.keyHandler);
  }

  disconnect() {
    window.removeEventListener('keydown', this.keyHandler);
  }

  // Touch handlers
  touchStart(event) {
    if (!event.touches || event.touches.length === 0) return;
    this.isSwiping = true;
    this.startX = event.touches[0].clientX;
    this.currentX = this.startX;
    this.imageTarget.style.transition = 'none';
  }

  touchMove(event) {
    if (!this.isSwiping) return;
    this.currentX = event.touches[0].clientX;
    const deltaX = this.currentX - this.startX;
    // Only move horizontally a bit with opacity cue
    const clamped = Math.max(-120, Math.min(120, deltaX));
    const opacity = 1 - Math.min(Math.abs(clamped) / 200, 0.4);
    this.imageTarget.style.transform = `translateX(${clamped}px)`;
    this.imageTarget.style.opacity = `${opacity}`;
  }

  touchEnd() {
    if (!this.isSwiping) return;
    const deltaX = this.currentX - this.startX;
    this.isSwiping = false;
    this.imageTarget.style.transition = 'transform 200ms ease, opacity 200ms ease';

    if (Math.abs(deltaX) > this.thresholdValue) {
      if (deltaX < 0) {
        // left swipe → next
        this.animateOut(-1, () => this.next());
      } else {
        // right swipe → prev
        this.animateOut(1, () => this.prev());
      }
    } else {
      this.resetImage();
    }
  }

  // Button/keyboard
  next() {
    if (!this.imagesValue || this.imagesValue.length === 0) return;
    const newIndex = (this.indexValue + 1) % this.imagesValue.length;
    this.setIndex(newIndex, -1);
  }

  prev() {
    if (!this.imagesValue || this.imagesValue.length === 0) return;
    const newIndex = (this.indexValue - 1 + this.imagesValue.length) % this.imagesValue.length;
    this.setIndex(newIndex, 1);
  }

  // Helpers
  setIndex(newIndex, direction = 0) {
    const oldImg = this.imageTarget;
    const newUrl = this.imagesValue[newIndex];
    if (!newUrl) return;

    // Slide out old, then swap src and slide in
    const outX = direction > 0 ? 100 : -100;
    const inX = direction > 0 ? -100 : 100;

    if (direction !== 0) {
      oldImg.style.transition = 'transform 150ms ease, opacity 150ms ease';
      oldImg.style.transform = `translateX(${outX}%)`;
      oldImg.style.opacity = '0';
      setTimeout(() => {
        oldImg.src = newUrl;
        oldImg.style.transition = 'none';
        oldImg.style.transform = `translateX(${inX}%)`;
        oldImg.style.opacity = '0';
        requestAnimationFrame(() => {
          oldImg.style.transition = 'transform 180ms ease, opacity 180ms ease';
          oldImg.style.transform = 'translateX(0)';
          oldImg.style.opacity = '1';
        });
      }, 150);
    } else {
      oldImg.src = newUrl;
      this.resetImage();
    }

    this.indexValue = newIndex;
    this.showIndex(newIndex);
  }

  showIndex(i) {
    if (this.hasIndexLabelTarget && this.imagesValue) {
      this.indexLabelTarget.textContent = `${i + 1} / ${this.imagesValue.length}`;
    }
  }

  animateOut(direction, done) {
    const off = direction > 0 ? 120 : -120;
    this.imageTarget.style.transform = `translateX(${off}px)`;
    this.imageTarget.style.opacity = '0';
    setTimeout(() => {
      this.resetImage();
      done && done();
    }, 180);
  }

  resetImage() {
    this.imageTarget.style.transform = 'translateX(0)';
    this.imageTarget.style.opacity = '1';
  }
}
