// Firebase Cloud Messaging service worker — required by the Firebase JS SDK
// for web push at all (foreground token retrieval AND background message
// delivery), independent of the VAPID key configured on the Dart side.
// Must live at this exact path (site root) — the SDK registers it by
// default at `/firebase-messaging-sw.js` and will not look elsewhere.
//
// Config mirrors DefaultFirebaseOptions.web in lib/firebase_options.dart —
// these values (apiKey, appId, etc.) are the public, client-embeddable
// Firebase config already shipped in that file and in web/index.html's
// Google Maps script tag; nothing here is a secret.

importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyC_H-8v4vl1iu2qDFhJXOVpQP-j8H2QxOw",
  appId: "1:832093698869:web:add42debd6754eda572a7c",
  messagingSenderId: "832093698869",
  projectId: "coffeecore-7111a",
  authDomain: "coffeecore-7111a.firebaseapp.com",
  storageBucket: "coffeecore-7111a.firebasestorage.app",
});

const messaging = firebase.messaging();

// Background/tab-closed delivery — the compat SDK shows a system
// notification automatically from the message's `notification` payload;
// this handler exists so the service worker has one registered (matches
// the same no-op-by-design pattern as firebaseMessagingBackgroundHandler
// in lib/services/push_notification_service.dart for mobile).
messaging.onBackgroundMessage((payload) => {
  // Intentionally minimal — see comment above.
});
