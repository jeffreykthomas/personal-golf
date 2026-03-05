function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content || "";
}

async function blobToBase64(blob) {
  const buffer = await blob.arrayBuffer();
  const bytes = new Uint8Array(buffer);
  let binary = "";
  bytes.forEach((b) => {
    binary += String.fromCharCode(b);
  });
  return btoa(binary);
}

export default class ConvaiClient {
  constructor({ signedUrlEndpoint, coachSessionId, onEvent, onError }) {
    this.signedUrlEndpoint = signedUrlEndpoint;
    this.coachSessionId = coachSessionId;
    this.onEvent = onEvent || (() => {});
    this.onError = onError || (() => {});
    this.ws = null;
    this.mediaRecorder = null;
    this.mediaStream = null;
  }

  async connect(options = {}) {
    const response = await fetch(this.signedUrlEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken(),
      },
      body: JSON.stringify({
        coach_session_id: this.coachSessionId,
        voice_name: options.voiceName,
        gender: options.gender,
      }),
    });

    if (!response.ok) {
      const payload = await response.json().catch(() => ({}));
      throw new Error(payload.error || "Unable to start voice session");
    }

    const payload = await response.json();
    if (!payload.signed_url) {
      throw new Error("Voice signed URL was not returned");
    }

    await this.openWebSocket(payload.signed_url);
    return payload;
  }

  async openWebSocket(url) {
    if (this.ws) {
      this.disconnect();
    }

    await new Promise((resolve, reject) => {
      this.ws = new WebSocket(url);
      this.ws.onopen = () => {
        this.onEvent({ type: "voice_connected" });
        resolve();
      };
      this.ws.onerror = () => {
        reject(new Error("Voice websocket failed to connect"));
      };
      this.ws.onclose = () => {
        this.onEvent({ type: "voice_disconnected" });
      };
      this.ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          this.onEvent(data);
        } catch (_error) {
          this.onEvent({ type: "voice_raw", payload: event.data });
        }
      };
    });
  }

  sendText(text) {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      return;
    }
    this.ws.send(JSON.stringify({ user_text: text }));
  }

  async startMicrophone() {
    if (this.mediaRecorder) {
      return;
    }

    this.mediaStream = await navigator.mediaDevices.getUserMedia({ audio: true });
    this.mediaRecorder = new MediaRecorder(this.mediaStream, { mimeType: "audio/webm" });

    this.mediaRecorder.addEventListener("dataavailable", async (event) => {
      if (!event.data || event.data.size === 0) {
        return;
      }
      if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
        return;
      }
      try {
        const base64 = await blobToBase64(event.data);
        this.ws.send(JSON.stringify({ user_audio_chunk: base64 }));
      } catch (error) {
        this.onError(error);
      }
    });

    this.mediaRecorder.start(250);
    this.onEvent({ type: "mic_started" });
  }

  stopMicrophone() {
    if (!this.mediaRecorder) {
      return;
    }

    this.mediaRecorder.stop();
    this.mediaRecorder = null;
    this.mediaStream?.getTracks()?.forEach((track) => track.stop());
    this.mediaStream = null;
    this.onEvent({ type: "mic_stopped" });
  }

  disconnect() {
    this.stopMicrophone();
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}
