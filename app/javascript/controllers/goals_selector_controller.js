import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['checkbox', 'submitButton', 'count'];

  connect() {
    // Initialize count and visual state on page load
    this.updateCount();
    this.updateVisualState();
  }

  toggleGoal(event) {
    const checkbox = event.target;

    // Update visual state for this checkbox
    this.updateCheckboxVisual(checkbox);

    // Update the count display
    this.updateCount();

    // Optional: Add haptic feedback on mobile
    if (navigator.vibrate) {
      navigator.vibrate(10);
    }
  }

  updateVisualState() {
    this.checkboxTargets.forEach((checkbox) => {
      this.updateCheckboxVisual(checkbox);
    });
  }

  updateCheckboxVisual(checkbox) {
    const label = checkbox.closest('label');
    const checkmark = label.querySelector('.checkbox-checkmark');
    const checkboxIndicator = label.querySelector('.checkbox-indicator');
    const card = label.querySelector('[class*="bg-dark-card"]');

    if (checkbox.checked) {
      // Show checkmark
      checkmark?.classList.remove('hidden');
      checkmark?.classList.add('block');

      // Update checkbox indicator
      checkboxIndicator?.classList.add('border-golf-green-500', 'bg-golf-green-500');
      checkboxIndicator?.classList.remove('border-gray-500');

      // Update card appearance
      card?.classList.add('border-golf-green-500', 'bg-dark-surface');
      card?.classList.remove('border-dark-border');
    } else {
      // Hide checkmark
      checkmark?.classList.remove('block');
      checkmark?.classList.add('hidden');

      // Reset checkbox indicator
      checkboxIndicator?.classList.remove('border-golf-green-500', 'bg-golf-green-500');
      checkboxIndicator?.classList.add('border-gray-500');

      // Reset card appearance
      card?.classList.remove('border-golf-green-500', 'bg-dark-surface');
      card?.classList.add('border-dark-border');
    }
  }

  updateCount() {
    const selectedCount = this.checkboxTargets.filter((checkbox) => checkbox.checked).length;

    if (this.hasCountTarget) {
      this.countTarget.textContent = selectedCount;
    }
  }

  submit(event) {
    // Allow form submission
    // Can add validation here if needed
  }
}
