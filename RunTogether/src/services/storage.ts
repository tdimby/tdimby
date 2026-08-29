import AsyncStorage from '@react-native-async-storage/async-storage';
import { RunRecord } from '@/types';

const RUNS_KEY = 'runtogether:runs';

export async function saveRun(run: RunRecord): Promise<void> {
  const all = await getRuns();
  all.unshift(run);
  await AsyncStorage.setItem(RUNS_KEY, JSON.stringify(all));
}

export async function getRuns(): Promise<RunRecord[]> {
  const raw = await AsyncStorage.getItem(RUNS_KEY);
  return raw ? (JSON.parse(raw) as RunRecord[]) : [];
}

export async function updateRun(id: string, patch: Partial<RunRecord>): Promise<void> {
  const all = await getRuns();
  const idx = all.findIndex((r) => r.id === id);
  if (idx === -1) return;
  all[idx] = { ...all[idx], ...patch };
  await AsyncStorage.setItem(RUNS_KEY, JSON.stringify(all));
}

export async function deleteRun(id: string): Promise<void> {
  const all = await getRuns();
  await AsyncStorage.setItem(RUNS_KEY, JSON.stringify(all.filter((r) => r.id !== id)));
}
