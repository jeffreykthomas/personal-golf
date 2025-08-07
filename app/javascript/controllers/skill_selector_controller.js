import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['radio', 'submitButton'];

  connect() {
    // Check if any radio is already selected
    this.updateSubmitButton();
  }

  selectLevel(event) {
    // Visual feedback is handled by CSS peer selectors
    // But we can add additional behavior here if needed
    
    // Update submit button state
    this.updateSubmitButton();
    
    // Optional: Add haptic feedback on mobile
    if (navigator.vibrate) {
      navigator.vibrate(10);
    }
  }

  updateSubmitButton() {
    const hasSelection = this.radioTargets.some(radio => radio.checked);
    
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
