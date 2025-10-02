import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['radio', 'submitButton'];

  connect() {
    // Check if any radio is already selected
    this.updateSubmitButton();
    this.updateVisualState();
  }

  selectLevel(event) {
    // Update visual state for all options
    this.updateVisualState();

    // Update submit button state
    this.updateSubmitButton();

    // Optional: Add haptic feedback on mobile
    if (navigator.vibrate) {
      navigator.vibrate(10);
    }
  }

  updateVisualState() {
    this.radioTargets.forEach((radio) => {
      const label = radio.closest('label');
      const indicator = label.querySelector('.radio-indicator');
      const card = label.querySelector('[class*="bg-dark-card"]');
      const indicatorRing = label.querySelector('.indicator-ring');

      if (radio.checked) {
        // Show the indicator
        indicator?.classList.remove('hidden');
        indicator?.classList.add('block');

        // Update card appearance with inline styles
        if (card) {
          card.style.borderColor = '#22c55e';
          card.style.backgroundColor = '#1a1a1a';
        }

        // Update indicator ring
        if (indicatorRing) {
          indicatorRing.style.borderColor = '#22c55e';
        }
      } else {
        // Hide the indicator
        indicator?.classList.remove('block');
        indicator?.classList.add('hidden');

        // Reset card appearance
        if (card) {
          card.style.borderColor = '';
          card.style.backgroundColor = '';
        }

        // Reset indicator ring
        if (indicatorRing) {
          indicatorRing.style.borderColor = '';
        }
      }
    });
  }

  updateSubmitButton() {
    const hasSelection = this.radioTargets.some((radio) => radio.checked);

    if (this.hasSubmitButtonTarget) {
      if (hasSelection) {
        this.submitButtonTarget.disabled = false;
        this.submitButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed');
        this.submitButtonTarget.classList.add('cursor-pointer');
      } else {
        this.submitButtonTarget.disabled = true;
        this.submitButtonTarget.classList.add('opacity-50', 'cursor-not-allowed');
        this.submitButtonTarget.classList.remove('cursor-pointer');
      }
    }
  }
}
