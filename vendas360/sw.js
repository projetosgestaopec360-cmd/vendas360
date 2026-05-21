var CACHE = 'vendas360-v5';
var ARQUIVOS = [
  '/manifest.json',
  '/icon-192.png',
  '/icon-512.png'
];

self.addEventListener('install', function(e) {
  e.waitUntil(
    caches.open(CACHE).then(function(cache) {
      return cache.addAll(ARQUIVOS.filter(function(f) {
        return f.indexOf('.png') < 0;
      }));
    }).catch(function() {})
  );
  self.skipWaiting();
});

self.addEventListener('activate', function(e) {
  e.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(keys.filter(function(k) {
        return k !== CACHE;
      }).map(function(k) {
        return caches.delete(k);
      }));
    })
  );
  self.clients.claim();
});

self.addEventListener('fetch', function(e) {
  // Ignorar esquemas não-HTTP (chrome-extension, etc.)
  if (!e.request.url.startsWith('http')) return;

  // Supabase e CDN sempre via rede
  if (e.request.url.indexOf('supabase') >= 0 ||
      e.request.url.indexOf('jsdelivr') >= 0 ||
      e.request.url.indexOf('google') >= 0) {
    return;
  }

  // Arquivos HTML: sempre busca da rede para garantir versao mais recente
  if (e.request.url.indexOf('.html') >= 0 || e.request.url.endsWith('/')) {
    e.respondWith(
      fetch(e.request).then(function(response) {
        var clone = response.clone();
        caches.open(CACHE).then(function(cache) { cache.put(e.request, clone); });
        return response;
      }).catch(function() {
        return caches.match(e.request);
      })
    );
    return;
  }

  // Outros recursos: cache first
  e.respondWith(
    caches.match(e.request).then(function(cached) {
      if (cached) return cached;
      return fetch(e.request).then(function(response) {
        var clone = response.clone();
        caches.open(CACHE).then(function(cache) { cache.put(e.request, clone); });
        return response;
      }).catch(function() {
        return cached;
      });
    })
  );
});
