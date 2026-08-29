import React, { createContext, useContext, useEffect, useState } from 'react';
import { onAuthStateChanged, signInAnonymously, updateProfile, User } from 'firebase/auth';
import { getFirebaseAuth } from '@/firebase';

interface AuthContextValue {
  user: User | null;
  loading: boolean;
  setDisplayName: (name: string) => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const auth = getFirebaseAuth();
    const unsub = onAuthStateChanged(auth, async (u) => {
      if (u) {
        setUser(u);
        setLoading(false);
      } else {
        await signInAnonymously(auth);
        // onAuthStateChanged will fire again with the new user.
      }
    });
    return unsub;
  }, []);

  async function setDisplayName(name: string) {
    const auth = getFirebaseAuth();
    if (!auth.currentUser) return;
    await updateProfile(auth.currentUser, { displayName: name });
    setUser({ ...auth.currentUser });
  }

  return (
    <AuthContext.Provider value={{ user, loading, setDisplayName }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
