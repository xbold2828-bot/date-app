// =============================================================================
// Firebase Cloud Messaging service worker (web only)
//
// Required for a background push on the web. Without this file at exactly this
// path, `FirebaseMessaging.getToken()` fails outright in a browser — so the web
// build silently registers no device at all, which is a failure with no error
// anywhere in the app.
//
// A service worker cannot see the page's config, so the Firebase values are
// repeated here. They mirror `DefaultFirebaseOptions.web` in
// lib/firebase_options.dart and must be kept in step with it. All of them are
// public identifiers, not secrets — a web API key identifies the project, it
// does not authorise anything.
//
// The compat build is used deliberately: a classic service worker cannot use ES
// module imports, and `importScripts` is the only loader available here.
// =============================================================================

importScripts(
  'https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'AIzaSyBcstzgL_3fMlRd0_cHG_svUGhWwJjYetE',
  appId: '1:664420294504:web:111fb6b08719aaa67680dd',
  messagingSenderId: '664420294504',
  projectId: 'dating-app-notification-ec341',
  authDomain: 'dating-app-notification-ec341.firebaseapp.com',
  storageBucket: 'dating-app-notification-ec341.firebasestorage.app',
});

const messaging = firebase.messaging();

// Background handler.
//
// Only reached for a DATA-ONLY push: when the payload carries a `notification`
// block the browser draws the notification itself, and handling it here as well
// would show two. The server sends `fcm_type: 'normal'` with a notification
// block for everything user-facing, so in practice this branch is the silent
// state-sync path.
messaging.onBackgroundMessage((payload) => {
  const data = payload.data || {};
  if (data.fcm_type !== 'dataOnly') return;

  // Nothing to draw for a silent push. Left as the seam for cache warming or
  // a badge update, if the web build ever wants one.
});

// Route a click back into the app rather than opening a second tab.
//
// `focus()` on an existing client is what stops a user who already has cozune
// open ending up with two copies of it; the postMessage hands the tap's data to
// the running page so it can deep-link exactly as the native handler does.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const data = (event.notification.data && event.notification.data.FCM_MSG)
    ? event.notification.data.FCM_MSG.data
    : event.notification.data || {};

  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clients) => {
        for (const client of clients) {
          if ('focus' in client) {
            client.postMessage({ type: 'push-notification-tap', data });
            return client.focus();
          }
        }
        return self.clients.openWindow('/');
      }),
  );
});
