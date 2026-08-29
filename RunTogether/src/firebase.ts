import { initializeApp, getApps, getApp } from 'firebase/app';
import { getAuth, initializeAuth, getReactNativePersistence } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Fill these in from your Firebase project settings, or provide via app.config.js / env.
const firebaseConfig = {
  apiKey: process.env.EXPO_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.EXPO_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.EXPO_PUBLIC_FIREBASE_SENDER_ID,
  appId: process.env.EXPO_PUBLIC_FIREBASE_APP_ID,
};

const appAlreadyExisted = getApps().length > 0;
export const firebaseApp = appAlreadyExisted ? getApp() : initializeApp(firebaseConfig);

export const auth = appAlreadyExisted
  ? getAuth(firebaseApp)
  : initializeAuth(firebaseApp, { persistence: getReactNativePersistence(AsyncStorage) });

export const db = getFirestore(firebaseApp);
