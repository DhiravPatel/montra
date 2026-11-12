/*
 * Montra push service worker.
 *
 * It does exactly two things: shows a notification when a Web Push message
 * arrives, and opens the notification's app path when it is clicked. It is
 * registered only after the user turns on browser notifications in
 * Settings → Notifications. It has no fetch handler, caches nothing and
 * never calls the API.
 *
 * Payloads come from the Montra API (ADR-047): {title, body, url, id, tag},
 * where `url` is an in-app path and the texts are safe summaries without
 * amounts.
 */
'use strict';

var FALLBACK_PATH = '/notifications';

/** Accepts only in-app absolute paths (no other sites, schemes or tricks). */
function safePath(value) {
  if (typeof value !== 'string' || value.charAt(0) !== '/' || value.charAt(1) === '/') {
    return FALLBACK_PATH;
  }
  if (value.indexOf('\\') !== -1 || value.indexOf(':') !== -1) return FALLBACK_PATH;
  return value;
}

function text(value, max) {
  return typeof value === 'string' ? value.slice(0, max) : '';
}

self.addEventListener('install', function () {
  // Nothing to cache: take over as soon as installed.
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

/** The push payload as an object ({} when missing or not JSON). */
function readPayload(event) {
  if (!event.data) return {};
  try {
    var parsed = event.data.json();
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

self.addEventListener('push', function (event) {
  var data = readPayload(event);
  var title = text(data.title, 160) || 'Montra';
  var options = {
    body: text(data.body, 500),
    icon: '/favicon.svg',
    // One notification per Montra notification, even if the push is retried.
    tag: text(data.id, 64) || undefined,
    data: { path: safePath(data.url) },
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var path = safePath(event.notification.data && event.notification.data.path);
  var target = new URL(path, self.location.origin).href;
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (windows) {
      for (var i = 0; i < windows.length; i += 1) {
        var client = windows[i];
        if (client.url === target && 'focus' in client) return client.focus();
      }
      return self.clients.openWindow(target);
    }),
  );
});
