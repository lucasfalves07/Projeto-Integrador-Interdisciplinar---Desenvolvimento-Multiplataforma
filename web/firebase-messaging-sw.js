/* Firebase Cloud Messaging Service Worker (Web)
 * Loads Firebase (compat) and initializes Messaging for background handling.
 * Uses minimal config with messagingSenderId; for advanced usage, provide full config.
 */

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

// Minimal init: only messagingSenderId is required in the SW
firebase.initializeApp({
  messagingSenderId: '504037958633',
});

// Retrieve an instance of Firebase Messaging so that it can handle background messages
const messaging = firebase.messaging();

// Optional: background message handler
// messaging.onBackgroundMessage((payload) => {
//   // Customize notification here if needed
//   // self.registration.showNotification(title, options);
// });

