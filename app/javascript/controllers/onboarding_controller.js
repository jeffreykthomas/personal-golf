import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static values = { currentStep: Number, totalSteps: Number };

  connect() {
    // Initialize onboarding flow
    // Can track progress and show animations
  }
}
