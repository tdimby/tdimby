import React, { createContext, useContext, useEffect, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

export type DistanceUnit = 'km' | 'mi';

interface SettingsContextValue {
  unit: DistanceUnit;
  setUnit: (unit: DistanceUnit) => void;
  autoPauseEnabled: boolean;
  setAutoPauseEnabled: (enabled: boolean) => void;
  loaded: boolean;
}

const UNIT_KEY = 'runtogether_unit';
const AUTO_PAUSE_KEY = 'runtogether_auto_pause';

const SettingsContext = createContext<SettingsContextValue | undefined>(undefined);

export function SettingsProvider({ children }: { children: React.ReactNode }) {
  const [unit, setUnitState] = useState<DistanceUnit>('km');
  const [autoPauseEnabled, setAutoPauseState] = useState(true);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    (async () => {
      const [storedUnit, storedAutoPause] = await Promise.all([
        AsyncStorage.getItem(UNIT_KEY),
        AsyncStorage.getItem(AUTO_PAUSE_KEY),
      ]);
      if (storedUnit === 'km' || storedUnit === 'mi') setUnitState(storedUnit);
      if (storedAutoPause != null) setAutoPauseState(storedAutoPause === 'true');
      setLoaded(true);
    })();
  }, []);

  function setUnit(next: DistanceUnit) {
    setUnitState(next);
    AsyncStorage.setItem(UNIT_KEY, next).catch(() => {});
  }

  function setAutoPauseEnabled(next: boolean) {
    setAutoPauseState(next);
    AsyncStorage.setItem(AUTO_PAUSE_KEY, String(next)).catch(() => {});
  }

  return (
    <SettingsContext.Provider value={{ unit, setUnit, autoPauseEnabled, setAutoPauseEnabled, loaded }}>
      {children}
    </SettingsContext.Provider>
  );
}

export function useSettings(): SettingsContextValue {
  const ctx = useContext(SettingsContext);
  if (!ctx) throw new Error('useSettings must be used within SettingsProvider');
  return ctx;
}
