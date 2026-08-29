import { initializeApp, getApps, getApp, FirebaseApp } from 'firebase/app';
import { getAuth, initializeAuth, Auth } from 'firebase/auth';
// getReactNativePersistence is only exported from the RN build of @firebase/auth, resolved by
// Metro's "react-native" package-export condition at bundle time — tsc doesn't apply that
// condition, so it can't see the type here even though it's present at runtime.
// @ts-expect-error - RN-only export, not visible to tsc's module resolution
import { getReactNativePersistence } from 'firebase/auth';
import { getFirestore, Firestore } from 'firebase/firestore';
import AsyncStorage from '@react-native-async-storage/async-storage';

const firebaseConfig = {
  apiKey: process.env.EXPO_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.EXPO_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.EXPO_PUBLIC_FIREBASE_SENDER_ID,
  appId: process.env.EXPO_PUBLIC_FIREBASE_APP_ID,
};

let firebaseApp: FirebaseApp | null = null;
let auth: Auth | null = null;
let db: Firestore | null = null;

/**
 * Lazily initializes Firebase on first use, instead of at module-import time.
 * A bad/missing config (e.g. env vars not injected into this build) then surfaces
 * as a normal thrown error inside a component/effect, catchable by an error
 * boundary — rather than crashing the whole JS bundle during evaluation, before
 * React ever mounts, which shows as a blank screen with no error message.
 */
function ensureFirebase(): { app: FirebaseApp; auth: Auth; db: Firestore } {
  if (!firebaseConfig.apiKey || !firebaseConfig.projectId) {
    throw new Error(
      'Firebase config is missing (EXPO_PUBLIC_FIREBASE_* env vars were not set for this build).'
    );
  }

  if (!firebaseApp) {
    const appAlreadyExisted = getApps().length > 0;
    firebaseApp = appAlreadyExisted ? getApp() : initializeApp(firebaseConfig);
    auth = appAlreadyExisted
      ? getAuth(firebaseApp)
      : initializeAuth(firebaseApp, { persistence: getReactNativePersistence(AsyncStorage) });
    db = getFirestore(firebaseApp);
  }

  return { app: firebaseApp, auth: auth!, db: db! };
}

export function getFirebaseAuth(): Auth {
  return ensureFirebase().auth;
}

export function getFirebaseDb(): Firestore {
  return ensureFirebase().db;
}
