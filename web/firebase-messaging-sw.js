importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js");

firebase.initializeApp({
  apiKey: "AIzaSyBMS5TGBrhbeg0ywkHr_htTsmZRcCkpEZE",
  authDomain: "attendiify.firebaseapp.com",
  projectId: "attendiify",
  storageBucket: "attendiify.firebasestorage.app",
  messagingSenderId: "582817926495",
  appId: "1:582817926495:web:86136f1d438c6430f2faea"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
