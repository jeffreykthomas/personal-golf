// app/javascript/controllers/swipeable_tip_controller.js
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['card', 'leftIndicator', 'rightIndicator', 'hint'];
  static values = {
    tipId: Number,
    threshold: { type: Number, default: 100 },
  };

  connect() {
    this.startX = 0;
    this.startY = 0;
    this.currentX = 0;
    this.currentY = 0;
    this.isAnimating = false;
    this.hasInteracted = false;
  }

  handleTouchStart(event) {
    if (this.isAnimating) return;

    this.startX = event.touches[0].clientX;
    this.startY = event.touches[0].clientY;
    this.cardTarget.style.transition = 'none';

    // Hide hint after first interaction
    if (this.hasHintTarget && !this.hasInteracted) {
      this.hintTarget.style.opacity = '0';
      this.hasInteracted = true;
    }
  }

  handleTouchMove(event) {
    if (this.isAnimating || !this.startX) return;

    event.preventDefault(); // Prevent scroll while swiping

    this.currentX = event.touches[0].clientX;
    this.currentY = event.touches[0].clientY;

    const deltaX = this.currentX - this.startX;
    const deltaY = this.currentY - this.startY;

    // Only handle horizontal swipes (prevent interference with vertical scroll)
    if (Math.abs(deltaX) > Math.abs(deltaY)) {
      this.updateCardPosition(deltaX);
      this.updateIndicators(deltaX);
    }
  }

  handleTouchEnd(event) {
    if (this.isAnimating) return;

    const deltaX = this.currentX - this.startX;
    const deltaY = this.currentY - this.startY;

    // Reset transition
    this.cardTarget.style.transition = 'transform 0.3s ease, opacity 0.3s ease';

    // Only process horizontal swipes
    if (Math.abs(deltaX) > Math.abs(deltaY)) {
      if (Math.abs(deltaX) > this.thresholdValue) {
        if (deltaX > 0) {
          this.executeSwipeRight();
        } else {
          this.executeSwipeLeft();
        }
      } else {
        this.resetCard();
      }
    } else {
      this.resetCard();
    }

    this.resetValues();
  }

  updateCardPosition(deltaX) {
    const rotation = deltaX * 0.1; // Subtle rotation
    const opacity = 1 - Math.abs(deltaX) / 300;

    this.cardTarget.style.transform = `translateX(${deltaX}px) rotate(${rotation}deg)`;
    this.cardTarget.style.opacity = Math.max(0.5, opacity);
  }

  updateIndicators(deltaX) {
    const progress = Math.min(Math.abs(deltaX) / this.thresholdValue, 1);

    if (deltaX > 0) {
      // Swiping right (save)
      this.rightIndicatorTarget.style.opacity = progress;
      this.leftIndicatorTarget.style.opacity = 0;
    } else {
      // Swiping left (skip)
      this.leftIndicatorTarget.style.opacity = progress;
      this.rightIndicatorTarget.style.opacity = 0;
    }
  }

  executeSwipeRight() {
    this.isAnimating = true;

    // Animate off screen
    this.cardTarget.style.transform = 'translateX(100%) rotate(15deg)';
    this.cardTarget.style.opacity = '0';

    // Show success feedback
    this.showFeedback('Saved! 💚', 'success');

    // Save tip after animation
    setTimeout(() => {
      this.save();
    }, 300);
  }

  executeSwipeLeft() {
    this.isAnimating = true;

    // Animate off screen
    this.cardTarget.style.transform = 'translateX(-100%) rotate(-15deg)';
    this.cardTarget.style.opacity = '0';

    // Show feedback
    this.showFeedback('Skipped', 'neutral');

    // Remove card after animation
    setTimeout(() => {
      this.skip();
    }, 300);
  }

  resetCard() {
    this.cardTarget.style.transform = 'translateX(0) rotate(0deg)';
    this.cardTarget.style.opacity = '1';
    this.leftIndicatorTarget.style.opacity = '0';
    this.rightIndicatorTarget.style.opacity = '0';
  }

  resetValues() {
    this.startX = 0;
    this.startY = 0;
    this.currentX = 0;
    this.currentY = 0;
  }

  // Button fallback methods
  async save() {
    try {
      const response = await fetch(`/tips/${this.tipIdValue}/save`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          Accept: 'text/vnd.turbo-stream.html',
        },
      });

      if (response.ok) {
        // Turbo will handle the response
      } else {
        throw new Error('Save failed');
      }
    } catch (error) {
      this.showFeedback('Save failed. Try again.', 'error');
      this.resetCard();
      this.isAnimating = false;
    }
  }

  skip() {
    // Load the next tip and mark current one as viewed
    this.loadNextTip(this.tipIdValue);
  }

  share() {
    if (navigator.share) {
      const tipTitle = this.element.querySelector('.text-heading').textContent;
      const tipContent = this.element.querySelector('.text-body').textContent;

      navigator.share({
        title: tipTitle,
        text: tipContent,
        url: window.location.href,
      });
    } else {
      // Fallback to copy
      this.copyToClipboard();
    }
  }

  handleTap(event) {
    // Only expand if not a button click
    if (!event.target.closest('button')) {
      // For now, just prevent default
      // Later we can add full-screen view
    }
  }

  loadNextTip(skipTipId = null) {
    // Build URL with skip tip ID if provided
    let url = '/tips/next';
    if (skipTipId) {
      url += `?skip_tip_id=${skipTipId}`;
    }

    // Load next tip via Turbo
    fetch(url, {
      headers: {
        Accept: 'text/vnd.turbo-stream.html',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
      },
    })
      .then((response) => response.text())
      .then((html) => {
        Turbo.renderStreamMessage(html);
      });
  }

  showFeedback(message, type = 'success') {
    const colors = {
      success: 'bg-golf-green-500',
      error: 'bg-red-500',
      neutral: 'bg-gray-500',
    };

    const toast = document.createElement('div');
    toast.className = `fixed top-20 left-1/2 transform -translate-x-1/2 ${colors[type]} text-white px-4 py-2 rounded-full z-50 transition-all duration-300`;
    toast.textContent = message;
    toast.style.transform = 'translateX(-50%) translateY(-20px)';
    toast.style.opacity = '0';

    document.body.appendChild(toast);

    // Animate in
    setTimeout(() => {
      toast.style.transform = 'translateX(-50%) translateY(0)';
      toast.style.opacity = '1';
    }, 10);

    // Animate out
    setTimeout(() => {
      toast.style.transform = 'translateX(-50%) translateY(-20px)';
      toast.style.opacity = '0';
      setTimeout(() => toast.remove(), 300);
    }, 2000);
  }

  copyToClipboard() {
    const tipTitle = this.element.querySelector('.text-heading').textContent;
    const tipContent = this.element.querySelector('.text-body').textContent;
    const text = `${tipTitle}\n\n${tipContent}`;

    navigator.clipboard.writeText(text).then(() => {
      this.showFeedback('Copied to clipboard!', 'success');
    });
  }
}
