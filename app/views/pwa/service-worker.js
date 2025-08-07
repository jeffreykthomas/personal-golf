// Service Worker with aggressive caching for instant loading
const CACHE_VERSION = 'v1';
const CACHE_NAME = `personal-golf-${CACHE_VERSION}`;
const OFFLINE_URL = '/offline.html';

// Resources to cache immediately on install
const PRECACHE_URLS = [
  '/',
  '/manifest.json',
  '/icon.png',
  '/icon.svg',
  '/sessions/new',
  '/users/new',
  '/offline.html',
];

// Cache strategies
const CACHE_STRATEGIES = {
  // Cache first for assets (CSS, JS, images)
  cacheFirst: [
    '/assets/',
    '/icon',
    '.css',
    '.js',
    '.png',
    '.jpg',
    '.jpeg',
    '.svg',
    '.woff',
    '.woff2',
  ],
  // Network first for API and dynamic content
  networkFirst: ['/tips', '/api/', '/auth/', '/sessions', '/users'],
  // Stale while revalidate for everything else
  staleWhileRevalidate: ['/'],
};

// Install event - cache essential resources
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE_NAME)
      .then((cache) => {
        console.log('Caching essential resources');
        return cache.addAll(
          PRECACHE_URLS.map((url) => {
            return new Request(url, { cache: 'reload' });
          }).filter((request) => {
            return request.url.startsWith(self.location.origin);
          })
        );
      })
      .then(() => self.skipWaiting())
      .catch((error) => {
        console.error('Failed to cache:', error);
      })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter(
              (cacheName) => cacheName.startsWith('personal-golf-') && cacheName !== CACHE_NAME
            )
            .map((cacheName) => caches.delete(cacheName))
        );
      })
      .then(() => self.clients.claim())
  );
});

// Fetch event - implement cache strategies
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-GET requests
  if (request.method !== 'GET') {
    return;
  }

  // Skip cross-origin requests
  if (url.origin !== location.origin) {
    return;
  }

  // Determine cache strategy
  const path = url.pathname;

  // Cache First Strategy (for static assets)
  if (CACHE_STRATEGIES.cacheFirst.some((pattern) => path.includes(pattern))) {
    event.respondWith(
      caches.match(request).then((response) => {
        if (response) {
          return response;
        }
        return fetch(request).then((response) => {
          if (!response || response.status !== 200 || response.type !== 'basic') {
            return response;
          }
          const responseToCache = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(request, responseToCache);
          });
          return response;
        });
      })
    );
    return;
  }

  // Network First Strategy (for dynamic content)
  if (CACHE_STRATEGIES.networkFirst.some((pattern) => path.includes(pattern))) {
    event.respondWith(
      fetch(request)
        .then((response) => {
          if (!response || response.status !== 200 || response.type !== 'basic') {
            return response;
          }
          const responseToCache = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(request, responseToCache);
          });
          return response;
        })
        .catch(() => {
          return caches.match(request);
        })
    );
    return;
  }

  // Stale While Revalidate (default strategy)
  event.respondWith(
    caches.match(request).then((response) => {
      const fetchPromise = fetch(request)
        .then((networkResponse) => {
          if (
            networkResponse &&
            networkResponse.status === 200 &&
            networkResponse.type === 'basic'
          ) {
            const responseToCache = networkResponse.clone();
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(request, responseToCache);
            });
          }
          return networkResponse;
        })
        .catch(() => {
          // If offline and no cache, show offline page
          if (request.mode === 'navigate') {
            return caches.match(OFFLINE_URL);
          }
        });

      return response || fetchPromise;
    })
  );
});

// Handle push notifications (if needed later)
self.addEventListener('push', async (event) => {
  const { title, options } = await event.data.json();
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window' }).then((clientList) => {
      for (let i = 0; i < clientList.length; i++) {
        let client = clientList[i];
        let clientPath = new URL(client.url).pathname;

        if (clientPath == event.notification.data.path && 'focus' in client) {
          return client.focus();
        }
      }

      if (clients.openWindow) {
        return clients.openWindow(event.notification.data.path);
      }
    })
  );
});
