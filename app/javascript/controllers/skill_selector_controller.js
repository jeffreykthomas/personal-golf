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
      const indicatorContainer = label.querySelector('.w-6.h-6.border-2.rounded-full');
      
      if (radio.checked) {
        // Show the indicator
        indicator?.classList.remove('hidden');
        indicator?.classList.add('block');
        
        // Update card appearance
        card?.classList.add('border-golf-green-500', 'bg-dark-surface');
        card?.classList.remove('border-dark-border');
        
        // Update indicator container
        indicatorContainer?.classList.add('border-golf-green-500');
        indicatorContainer?.classList.remove('border-gray-500');
      } else {
        // Hide the indicator
        indicator?.classList.remove('block');
        indicator?.classList.add('hidden');
        
        // Reset card appearance
        card?.classList.remove('border-golf-green-500', 'bg-dark-surface');
        card?.classList.add('border-dark-border');
        
        // Reset indicator container
        indicatorContainer?.classList.remove('border-golf-green-500');
        indicatorContainer?.classList.add('border-gray-500');
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
