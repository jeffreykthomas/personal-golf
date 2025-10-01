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

      if (radio.checked) {
        indicator?.classList.remove('scale-0');
        indicator?.classList.add('scale-100');
      } else {
        indicator?.classList.remove('scale-100');
        indicator?.classList.add('scale-0');
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
