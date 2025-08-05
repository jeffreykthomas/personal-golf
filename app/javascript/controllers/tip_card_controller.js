import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static values = { tipId: Number };

  connect() {
    // Simple controller for tip card interactions
    // Can be extended later with more functionality
  }
}
