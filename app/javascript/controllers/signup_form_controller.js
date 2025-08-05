import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['submit'];

  connect() {
    this.element.addEventListener('submit', this.handleSubmit.bind(this));
  }

  disconnect() {
    this.element.removeEventListener('submit', this.handleSubmit.bind(this));
  }

  handleSubmit(event) {
    // Don't prevent default - let Rails handle the form submission

    // Update button to show loading state
    const button = this.submitTarget;
    const originalText = button.value;

    // Add loading spinner
    button.value = '';
    button.disabled = true;
    button.classList.add('flex', 'items-center', 'justify-center');
    button.innerHTML = `
      <svg class="animate-spin h-5 w-5 text-gray-800" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
    `;
  }
}
