# PWA Features & Offline Capabilities

## Overview

This document details the Progressive Web App features of Personal Golf, focusing on offline functionality, performance optimization, and native-like capabilities.

## PWA Configuration

### Manifest Configuration

```json
// src/pwa/manifest.json
{
  "name": "Personal Golf - Play Your Best",
  "short_name": "Personal Golf",
  "description": "Track and improve your golf game with personalized tips and course strategies",
  "display": "standalone",
  "orientation": "portrait",
  "theme_color": "#1976d2",
  "background_color": "#ffffff",
  "start_url": "/",
  "scope": "/",
  "icons": [
    {
      "src": "/icons/icon-72x72.png",
      "sizes": "72x72",
      "type": "image/png"
    },
    {
      "src": "/icons/icon-128x128.png",
      "sizes": "128x128",
      "type": "image/png"
    },
    {
      "src": "/icons/icon-192x192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/icons/icon-512x512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any maskable"
    }
  ],
  "categories": ["sports", "lifestyle"],
  "screenshots": [
    {
      "src": "/screenshots/home.png",
      "sizes": "1080x1920",
      "type": "image/png"
    },
    {
      "src": "/screenshots/tips.png",
      "sizes": "1080x1920",
      "type": "image/png"
    }
  ],
  "shortcuts": [
    {
      "name": "My Tips",
      "short_name": "Tips",
      "description": "View your saved tips",
      "url": "/tips",
      "icons": [{ "src": "/icons/tips.png", "sizes": "96x96" }]
    },
    {
      "name": "Practice",
      "short_name": "Practice",
      "description": "Today's practice routine",
      "url": "/practice",
      "icons": [{ "src": "/icons/practice.png", "sizes": "96x96" }]
    }
  ]
}
```

## Service Worker Implementation

### Registration

```typescript
// src/boot/register-service-worker.ts
import { register } from 'register-service-worker';
import { Notify } from 'quasar';

if (process.env.PROD) {
  register(process.env.SERVICE_WORKER_FILE, {
    ready(registration) {
      console.log('Service worker is active.');
    },

    registered(registration) {
      console.log('Service worker has been registered.');
    },

    cached(registration) {
      console.log('Content has been cached for offline use.');
    },

    updatefound(registration) {
      console.log('New content is downloading.');
    },

    updated(registration) {
      console.log('New content is available; please refresh.');
      Notify.create({
        message: 'New version available!',
        actions: [
          {
            label: 'Refresh',
            color: 'white',
            handler: () => {
              registration.waiting?.postMessage({ type: 'SKIP_WAITING' });
              window.location.reload();
            },
          },
        ],
      });
    },

    offline() {
      console.log('No internet connection found. App is running in offline mode.');
      Notify.create({
        message: 'You are offline',
        color: 'negative',
        icon: 'wifi_off',
      });
    },

    error(error) {
      console.error('Error during service worker registration:', error);
    },
  });
}
```

### Service Worker Strategy

```javascript
// src-pwa/custom-service-worker.js
import { precacheAndRoute } from 'workbox-precaching';
import { registerRoute } from 'workbox-routing';
import { StaleWhileRevalidate, CacheFirst, NetworkFirst } from 'workbox-strategies';
import { ExpirationPlugin } from 'workbox-expiration';
import { CacheableResponsePlugin } from 'workbox-cacheable-response';
import { BackgroundSyncPlugin } from 'workbox-background-sync';

// Precache all static assets
precacheAndRoute(self.__WB_MANIFEST);

// Cache strategies
const CACHE_NAMES = {
  tips: 'tips-cache-v1',
  images: 'images-cache-v1',
  api: 'api-cache-v1',
  courses: 'courses-cache-v1',
};

// API calls - Network first, fallback to cache
registerRoute(
  ({ url }) => url.pathname.startsWith('/api/'),
  new NetworkFirst({
    cacheName: CACHE_NAMES.api,
    networkTimeoutSeconds: 5,
    plugins: [
      new CacheableResponsePlugin({
        statuses: [0, 200],
      }),
      new ExpirationPlugin({
        maxEntries: 50,
        maxAgeSeconds: 60 * 60 * 24, // 24 hours
      }),
    ],
  }),
);

// Images - Cache first
registerRoute(
  ({ request }) => request.destination === 'image',
  new CacheFirst({
    cacheName: CACHE_NAMES.images,
    plugins: [
      new CacheableResponsePlugin({
        statuses: [0, 200],
      }),
      new ExpirationPlugin({
        maxEntries: 100,
        maxAgeSeconds: 60 * 60 * 24 * 30, // 30 days
        purgeOnQuotaError: true,
      }),
    ],
  }),
);

// Tips data - Stale while revalidate
registerRoute(
  ({ url }) => url.pathname.includes('/tips'),
  new StaleWhileRevalidate({
    cacheName: CACHE_NAMES.tips,
    plugins: [
      new CacheableResponsePlugin({
        statuses: [0, 200],
      }),
    ],
  }),
);

// Background sync for offline actions
const bgSyncPlugin = new BackgroundSyncPlugin('offline-queue', {
  maxRetentionTime: 24 * 60, // Retry for up to 24 hours
});

registerRoute(
  /\/api\/tips\/save/,
  new NetworkFirst({
    plugins: [bgSyncPlugin],
  }),
  'POST',
);

// Handle offline fallback
const FALLBACK_HTML_URL = '/offline.html';
const FALLBACK_IMAGE_URL = '/images/offline-placeholder.svg';

// Install event - cache offline pages
self.addEventListener('install', async (event) => {
  event.waitUntil(
    caches.open(CACHE_NAMES.tips).then((cache) => {
      return cache.addAll([FALLBACK_HTML_URL, FALLBACK_IMAGE_URL, '/css/offline.css']);
    }),
  );
});

// Fetch event - provide offline fallbacks
self.addEventListener('fetch', (event) => {
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request).catch(() => {
        return caches.match(FALLBACK_HTML_URL);
      }),
    );
  }
});
```

## Offline Data Management

### IndexedDB Schema

```typescript
// src/services/offline-storage.ts
import Dexie, { Table } from 'dexie';

interface OfflineTip {
  id: string;
  title: string;
  content: string;
  category: string;
  savedAt: Date;
  syncStatus: 'synced' | 'pending' | 'error';
}

interface PendingAction {
  id: string;
  type: 'save_tip' | 'create_tip' | 'update_profile';
  payload: any;
  timestamp: Date;
  retryCount: number;
  lastError?: string;
}

class GolfDatabase extends Dexie {
  tips!: Table<OfflineTip>;
  pendingActions!: Table<PendingAction>;
  userProfile!: Table<any>;
  courses!: Table<any>;

  constructor() {
    super('PersonalGolfDB');

    this.version(1).stores({
      tips: 'id, category, savedAt, syncStatus',
      pendingActions: 'id, type, timestamp',
      userProfile: 'uid',
      courses: 'id, name, [location.lat+location.lng]',
    });
  }
}

export const db = new GolfDatabase();

// Offline storage service
export class OfflineStorageService {
  async saveTipOffline(tip: OfflineTip): Promise<void> {
    await db.tips.put({
      ...tip,
      syncStatus: 'pending',
    });

    // Queue sync action
    await this.queueAction({
      type: 'save_tip',
      payload: { tipId: tip.id },
    });
  }

  async queueAction(action: Omit<PendingAction, 'id' | 'timestamp' | 'retryCount'>): Promise<void> {
    await db.pendingActions.add({
      ...action,
      id: `${action.type}_${Date.now()}`,
      timestamp: new Date(),
      retryCount: 0,
    });
  }

  async syncPendingActions(): Promise<void> {
    const actions = await db.pendingActions.toArray();

    for (const action of actions) {
      try {
        await this.executeAction(action);
        await db.pendingActions.delete(action.id);
      } catch (error) {
        await db.pendingActions.update(action.id, {
          retryCount: action.retryCount + 1,
          lastError: error.message,
        });
      }
    }
  }

  private async executeAction(action: PendingAction): Promise<void> {
    switch (action.type) {
      case 'save_tip':
        await api.saveTip(action.payload.tipId);
        break;
      case 'create_tip':
        await api.createTip(action.payload);
        break;
      case 'update_profile':
        await api.updateProfile(action.payload);
        break;
    }
  }
}
```

### Sync Manager

```typescript
// src/services/sync-manager.ts
import { db, OfflineStorageService } from './offline-storage';

export class SyncManager {
  private syncInProgress = false;
  private offlineStorage = new OfflineStorageService();

  async initializeSync(): Promise<void> {
    // Listen for online/offline events
    window.addEventListener('online', () => this.handleOnline());
    window.addEventListener('offline', () => this.handleOffline());

    // Check sync on app startup
    if (navigator.onLine) {
      await this.performSync();
    }

    // Periodic sync every 5 minutes when online
    setInterval(
      () => {
        if (navigator.onLine && !this.syncInProgress) {
          this.performSync();
        }
      },
      5 * 60 * 1000,
    );
  }

  private async handleOnline(): Promise<void> {
    console.log('App is online, starting sync...');
    await this.performSync();
  }

  private handleOffline(): void {
    console.log('App is offline, caching enabled');
    // Update UI to show offline status
    this.updateOfflineUI(true);
  }

  async performSync(): Promise<void> {
    if (this.syncInProgress) return;

    this.syncInProgress = true;

    try {
      // Sync pending actions
      await this.offlineStorage.syncPendingActions();

      // Update cached tips
      await this.syncTips();

      // Update user profile
      await this.syncUserProfile();

      // Update UI
      this.updateSyncStatus('success');
    } catch (error) {
      console.error('Sync failed:', error);
      this.updateSyncStatus('error');
    } finally {
      this.syncInProgress = false;
    }
  }

  private async syncTips(): Promise<void> {
    // Get latest tips from server
    const response = await fetch('/api/tips/sync', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        lastSync: await this.getLastSyncTime(),
      }),
    });

    const { tips, deleted } = await response.json();

    // Update local database
    await db.transaction('rw', db.tips, async () => {
      // Add/update new tips
      for (const tip of tips) {
        await db.tips.put({
          ...tip,
          syncStatus: 'synced',
        });
      }

      // Remove deleted tips
      for (const tipId of deleted) {
        await db.tips.delete(tipId);
      }
    });

    await this.setLastSyncTime(new Date());
  }

  private async getLastSyncTime(): Promise<Date | null> {
    const syncMeta = localStorage.getItem('lastSyncTime');
    return syncMeta ? new Date(syncMeta) : null;
  }

  private async setLastSyncTime(time: Date): Promise<void> {
    localStorage.setItem('lastSyncTime', time.toISOString());
  }

  private updateOfflineUI(isOffline: boolean): void {
    document.body.classList.toggle('offline-mode', isOffline);
  }

  private updateSyncStatus(status: 'success' | 'error' | 'syncing'): void {
    // Emit event for UI updates
    window.dispatchEvent(new CustomEvent('sync-status', { detail: status }));
  }
}
```

## Performance Optimizations

### 1. App Shell Architecture

```vue
<!-- src/layouts/MainLayout.vue -->
<template>
  <q-layout view="lHh Lpr lFf">
    <q-header elevated>
      <q-toolbar>
        <q-btn flat dense round icon="menu" aria-label="Menu" @click="toggleLeftDrawer" />
        <q-toolbar-title> Personal Golf </q-toolbar-title>
        <q-btn v-if="!isOnline" flat dense icon="wifi_off" color="negative">
          <q-tooltip>You are offline</q-tooltip>
        </q-btn>
      </q-toolbar>
    </q-header>

    <q-drawer v-model="leftDrawerOpen" show-if-above bordered>
      <!-- Navigation skeleton loaded immediately -->
      <q-list>
        <template v-if="!menuLoaded">
          <q-item v-for="i in 5" :key="i">
            <q-skeleton type="text" />
          </q-item>
        </template>
        <template v-else>
          <!-- Actual menu items -->
        </template>
      </q-list>
    </q-drawer>

    <q-page-container>
      <router-view v-slot="{ Component }">
        <keep-alive :include="cachedViews">
          <component :is="Component" />
        </keep-alive>
      </router-view>
    </q-page-container>
  </q-layout>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useQuasar } from 'quasar';

const $q = useQuasar();
const isOnline = ref(navigator.onLine);
const menuLoaded = ref(false);
const cachedViews = ['TipsPage', 'HomePage'];

// Lazy load menu after app shell
onMounted(async () => {
  const { loadMenu } = await import('./menu-loader');
  await loadMenu();
  menuLoaded.value = true;
});

// Monitor online status
window.addEventListener('online', () => {
  isOnline.value = true;
  $q.notify({
    message: 'Back online!',
    color: 'positive',
    icon: 'wifi',
  });
});

window.addEventListener('offline', () => {
  isOnline.value = false;
});
</script>
```

### 2. Image Optimization

```typescript
// src/composables/useOptimizedImage.ts
export function useOptimizedImage() {
  const getOptimizedUrl = (url: string, options: ImageOptions = {}) => {
    const { width = 800, quality = 80, format = 'webp' } = options;

    // If using Firebase Storage, append transformation params
    if (url.includes('firebasestorage.googleapis.com')) {
      return `${url}?w=${width}&q=${quality}&fm=${format}`;
    }

    return url;
  };

  const preloadImage = (url: string): Promise<void> => {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => resolve();
      img.onerror = reject;
      img.src = url;
    });
  };

  const lazyLoadImage = (element: HTMLImageElement, src: string, placeholder?: string) => {
    if (placeholder) {
      element.src = placeholder;
    }

    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          element.src = src;
          observer.unobserve(element);
        }
      });
    });

    observer.observe(element);
  };

  return {
    getOptimizedUrl,
    preloadImage,
    lazyLoadImage,
  };
}
```

### 3. Code Splitting

```typescript
// src/router/routes.ts
const routes: RouteRecordRaw[] = [
  {
    path: '/',
    component: () => import('layouts/MainLayout.vue'),
    children: [
      {
        path: '',
        component: () => import('pages/IndexPage.vue'),
      },
      {
        path: 'tips',
        component: () => import('pages/TipsPage.vue'),
      },
      {
        path: 'practice',
        component: () =>
          import(
            /* webpackChunkName: "practice" */
            'pages/PracticePage.vue'
          ),
      },
      {
        path: 'courses/:id',
        component: () =>
          import(
            /* webpackChunkName: "courses" */
            'pages/CourseDetailPage.vue'
          ),
      },
    ],
  },
];
```

## Native Features

### 1. Install Prompt

```typescript
// src/composables/useInstallPrompt.ts
import { ref } from 'vue';

export function useInstallPrompt() {
  const deferredPrompt = ref<any>(null);
  const showInstallButton = ref(false);

  // Listen for install prompt
  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredPrompt.value = e;
    showInstallButton.value = true;
  });

  const installApp = async () => {
    if (!deferredPrompt.value) return;

    deferredPrompt.value.prompt();
    const { outcome } = await deferredPrompt.value.userChoice;

    if (outcome === 'accepted') {
      console.log('User accepted install prompt');
    }

    deferredPrompt.value = null;
    showInstallButton.value = false;
  };

  // Check if already installed
  const isInstalled = ref(
    window.matchMedia('(display-mode: standalone)').matches ||
      (window.navigator as any).standalone === true,
  );

  return {
    showInstallButton,
    installApp,
    isInstalled,
  };
}
```

### 2. Share API

```typescript
// src/composables/useShare.ts
export function useShare() {
  const canShare = ref('share' in navigator);

  const shareTip = async (tip: Tip) => {
    if (!canShare.value) {
      // Fallback to copy link
      await copyToClipboard(tip.shareUrl);
      return;
    }

    try {
      await navigator.share({
        title: tip.title,
        text: tip.content.substring(0, 100) + '...',
        url: tip.shareUrl,
      });
    } catch (error) {
      if (error.name !== 'AbortError') {
        console.error('Share failed:', error);
      }
    }
  };

  return { canShare, shareTip };
}
```

### 3. Notifications

```typescript
// src/services/notification-service.ts
export class NotificationService {
  async requestPermission(): Promise<boolean> {
    if (!('Notification' in window)) return false;

    if (Notification.permission === 'granted') return true;

    if (Notification.permission !== 'denied') {
      const permission = await Notification.requestPermission();
      return permission === 'granted';
    }

    return false;
  }

  async showNotification(title: string, options: NotificationOptions = {}) {
    if (!(await this.requestPermission())) return;

    const registration = await navigator.serviceWorker.ready;

    await registration.showNotification(title, {
      icon: '/icons/icon-192x192.png',
      badge: '/icons/badge-72x72.png',
      vibrate: [200, 100, 200],
      ...options,
    });
  }

  async schedulePracticeReminder(time: Date) {
    // Use Background Sync API to schedule
    const registration = await navigator.serviceWorker.ready;
    await registration.sync.register('practice-reminder');

    // Store reminder time
    localStorage.setItem('practiceReminderTime', time.toISOString());
  }
}
```

## Testing PWA Features

### 1. Lighthouse Audit

```bash
# Run Lighthouse CI
npm install -g @lhci/cli
lhci autorun
```

### 2. PWA Checklist

- [ ] Service Worker registered and active
- [ ] Offline page loads successfully
- [ ] App installable on mobile/desktop
- [ ] All resources cached properly
- [ ] Background sync works
- [ ] Push notifications functional
- [ ] App passes Lighthouse PWA audit
- [ ] HTTPS enabled
- [ ] Valid Web App Manifest
- [ ] Splash screens configured
