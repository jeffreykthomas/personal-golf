import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['button'];

  save(event) {
    // Disable the button to prevent double submission
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true;
      this.buttonTarget.textContent = 'Saving...';
    }
  }
}
