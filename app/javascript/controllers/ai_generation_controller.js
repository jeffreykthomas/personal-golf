// app/javascript/controllers/ai_generation_controller.js
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['button', 'message'];

  connect() {
    this.isGenerating = false;
  }

  async requestTips(event) {
    if (this.isGenerating) return;

    const button = event.target;
    const messageElement = document.getElementById('ai-status-message');

    // Update UI to show loading state
    this.setLoadingState(button, messageElement);

    try {
      const response = await fetch('/tips/request_ai_tips', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          Accept: 'application/json',
        },
        body: JSON.stringify({ count: 5 }),
      });

      const data = await response.json();

      if (response.ok) {
        this.setSuccessState(button, messageElement, data);
        // Check for new tips after a delay
        setTimeout(() => this.checkForNewTips(), 3000);
      } else {
        this.setErrorState(button, messageElement, data);
      }
    } catch (error) {
      console.error('AI generation request failed:', error);
      this.setErrorState(button, messageElement, { error: 'Request failed. Please try again.' });
    }
  }

  setLoadingState(button, messageElement) {
    this.isGenerating = true;
    button.disabled = true;
    button.innerHTML = '⏳ Generating...';
    button.classList.add('opacity-75', 'cursor-not-allowed');

    if (messageElement) {
      messageElement.textContent = 'AI is creating personalized tips for you...';
      messageElement.className = 'text-caption text-blue-400';
    }
  }

  setSuccessState(button, messageElement, data) {
    button.innerHTML = '✅ Tips Requested!';
    button.classList.remove('opacity-75', 'cursor-not-allowed');
    button.classList.add('bg-green-600');

    if (messageElement) {
      messageElement.textContent = data.message || 'Tips are being generated!';
      messageElement.className = 'text-caption text-green-400';
    }

    // Reset button after delay
    setTimeout(() => {
      this.resetButton(button, messageElement);
    }, 5000);
  }

  setErrorState(button, messageElement, data) {
    this.isGenerating = false;
    button.disabled = false;
    button.innerHTML = '❌ Try Again';
    button.classList.remove('opacity-75', 'cursor-not-allowed');
    button.classList.add('bg-red-600');

    if (messageElement) {
      messageElement.textContent = data.error || 'Generation failed. Please try again.';
      messageElement.className = 'text-caption text-red-400';
    }

    // Reset button after delay
    setTimeout(() => {
      this.resetButton(button, messageElement);
    }, 3000);
  }

  resetButton(button, messageElement) {
    this.isGenerating = false;
    button.disabled = false;
    button.innerHTML = '🤖 Generate Personalized Tips';
    button.className = button.className.replace(/bg-(green|red)-600/g, '');

    if (messageElement) {
      messageElement.textContent = 'AI can create tips just for you based on your progress!';
      messageElement.className = 'text-caption';
    }
  }

  async checkForNewTips() {
    // Check if new tips are available by calling the next tip endpoint
    try {
      const response = await fetch('/tips/next', {
        headers: {
          Accept: 'text/vnd.turbo-stream.html',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        },
      });

      if (response.ok) {
        const html = await response.text();
        // Let Turbo handle the response to update the UI
        Turbo.renderStreamMessage(html);
      }
    } catch (error) {
      console.log('Could not check for new tips:', error);
    }
  }
}
