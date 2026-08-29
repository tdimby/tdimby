import { initializeApp, getApps, getApp } from 'firebase/app';
import { getAuth, initializeAuth } from 'firebase/auth';
// getReactNativePersistence is only exported from the RN build of @firebase/auth, resolved by
// Metro's "react-native" package-export condition at bundle time — tsc doesn't apply that
// condition, so it can't see the type here even though it's present at runtime.
// @ts-expect-error - RN-only export, not visible to tsc's module resolution
import { getReactNativePersistence } from 'firebase/auth';
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
