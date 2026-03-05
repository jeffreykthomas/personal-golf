import { Controller } from "@hotwired/stimulus"

const DEFAULT_CENTER = { lng: -95.7129, lat: 37.0902 } // US fallback
const METERS_TO_YARDS = 1.09361

export default class extends Controller {
  static values = {
    accessToken: String,
    payload: Object
  }

  static targets = [
    "canvas",
    "status",
    "distance",
    "targetLabel"
  ]

  connect() {
    this.userCoords = null
    this.targetCoords = null
    this.geoWatchId = null

    if (!this.accessTokenValue) {
      this.setStatus("Map unavailable: missing MAPBOX_ACCESS_TOKEN.")
      return
    }

    this.waitForMapbox()
  }

  disconnect() {
    if (this.geoWatchId) navigator.geolocation.clearWatch(this.geoWatchId)
    if (this.map) this.map.remove()
  }

  waitForMapbox() {
    if (!window.mapboxgl) {
      this.setStatus("Loading map...")
      window.setTimeout(() => this.waitForMapbox(), 150)
      return
    }

    this.initializeMap()
  }

  async initializeMap() {
    window.mapboxgl.accessToken = this.accessTokenValue

    const center = await this.resolveCourseCenter()
    this.map = new window.mapboxgl.Map({
      container: this.canvasTarget,
      style: "mapbox://styles/mapbox/satellite-streets-v12",
      center: [center.lng, center.lat],
      zoom: 16
    })

    this.map.addControl(new window.mapboxgl.NavigationControl(), "top-right")

    this.map.on("load", () => {
      this.setStatus("Tap map to choose a target.")
      this.renderFutureTargets()
      this.startLocationTracking()
    })

    this.map.on("click", (event) => {
      this.setTarget({
        lng: event.lngLat.lng,
        lat: event.lngLat.lat
      }, "Tapped target")
    })
  }

  async resolveCourseCenter() {
    const explicitCoords = this.payloadValue?.course?.coordinates
    if (explicitCoords?.lat && explicitCoords?.lng) {
      return { lat: explicitCoords.lat, lng: explicitCoords.lng }
    }

    const query = this.payloadValue?.course?.location
    if (!query) return DEFAULT_CENTER

    try {
      const encoded = encodeURIComponent(query)
      const response = await fetch(
        `https://api.mapbox.com/geocoding/v5/mapbox.places/${encoded}.json?limit=1&access_token=${this.accessTokenValue}`
      )
      const data = await response.json()
      const first = data?.features?.[0]?.center

      if (!first || first.length < 2) return DEFAULT_CENTER
      return { lng: first[0], lat: first[1] }
    } catch (error) {
      return DEFAULT_CENTER
    }
  }

  renderFutureTargets() {
    const targets = this.payloadValue?.targets || []
    if (!Array.isArray(targets) || targets.length === 0) return

    targets.forEach((target) => {
      if (!target?.lat || !target?.lng) return
      const el = document.createElement("button")
      el.className = "w-3 h-3 rounded-full bg-accent-500 border border-white/80"
      el.title = target.name || "Target"
      el.addEventListener("click", () => {
        this.setTarget({ lat: target.lat, lng: target.lng }, target.name || "Target")
      })

      new window.mapboxgl.Marker({ element: el })
        .setLngLat([target.lng, target.lat])
        .addTo(this.map)
    })
  }

  startLocationTracking() {
    if (!navigator.geolocation) {
      this.setStatus("Geolocation is not supported in this browser.")
      return
    }

    this.geoWatchId = navigator.geolocation.watchPosition(
      (position) => {
        const next = {
          lat: position.coords.latitude,
          lng: position.coords.longitude
        }

        if (!this.userCoords) {
          this.userCoords = next
        } else {
          // Light smoothing to reduce jumpy yardages.
          this.userCoords = {
            lat: (this.userCoords.lat * 0.7) + (next.lat * 0.3),
            lng: (this.userCoords.lng * 0.7) + (next.lng * 0.3)
          }
        }

        this.updateUserMarker()
        this.refreshDistance()
      },
      () => this.setStatus("Location blocked. Enable GPS for live yardages."),
      {
        enableHighAccuracy: true,
        maximumAge: 2000,
        timeout: 15000
      }
    )
  }

  updateUserMarker() {
    if (!this.userCoords) return
    if (!this.userMarker) {
      const el = document.createElement("div")
      el.className = "w-4 h-4 rounded-full bg-sky-400 border-2 border-white shadow"
      this.userMarker = new window.mapboxgl.Marker({ element: el })
        .setLngLat([this.userCoords.lng, this.userCoords.lat])
        .addTo(this.map)
      return
    }

    this.userMarker.setLngLat([this.userCoords.lng, this.userCoords.lat])
  }

  setTarget(coords, label) {
    this.targetCoords = coords
    this.targetLabelTarget.textContent = label

    if (!this.targetMarker) {
      const el = document.createElement("div")
      el.className = "w-4 h-4 rounded-full bg-red-500 border-2 border-white shadow"
      this.targetMarker = new window.mapboxgl.Marker({ element: el })
        .setLngLat([coords.lng, coords.lat])
        .addTo(this.map)
    } else {
      this.targetMarker.setLngLat([coords.lng, coords.lat])
    }

    this.refreshDistance()
  }

  refreshDistance() {
    if (!this.targetCoords) {
      this.distanceTarget.textContent = "--"
      return
    }

    if (!this.userCoords) {
      this.setStatus("Waiting for GPS lock...")
      this.distanceTarget.textContent = "--"
      return
    }

    const meters = this.haversine(this.userCoords, this.targetCoords)
    const yards = Math.round(meters * METERS_TO_YARDS)
    this.distanceTarget.textContent = `${yards} yd`
    this.setStatus("Live GPS distance")
  }

  setStatus(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }

  haversine(a, b) {
    const toRad = (deg) => deg * Math.PI / 180
    const earthRadiusMeters = 6371000
    const dLat = toRad(b.lat - a.lat)
    const dLng = toRad(b.lng - a.lng)
    const s1 = Math.sin(dLat / 2)
    const s2 = Math.sin(dLng / 2)
    const x = (s1 * s1) + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * (s2 * s2)
    const c = 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x))
    return earthRadiusMeters * c
  }
}
