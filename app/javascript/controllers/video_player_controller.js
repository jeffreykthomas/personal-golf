import { Controller } from '@hotwired/stimulus';

// data-controller="video-player"
// Usage: put on a container with a <video data-video-player-target="video"> child
export default class extends Controller {
  static targets = ['video'];

  connect() {
    // no-op
  }

  async openFullscreen() {
    const video = this.hasVideoTarget ? this.videoTarget : this.element.querySelector('video');
    if (!video) return;
    try {
      // Ensure controls in fullscreen
      video.setAttribute('controls', 'true');
      if (video.requestFullscreen) {
        await video.requestFullscreen();
      } else if (video.webkitEnterFullscreen) {
        // iOS Safari
        video.webkitEnterFullscreen();
      }
      // Play if paused
      if (video.paused) {
        await video.play().catch(() => {});
      }
    } catch (_) {}
  }
}
