import { useCallback, useEffect, useRef, useState } from 'react';
import { GeoPoint, RunRecord } from '@/types';
import { onLocationPoint, requestLocationPermissions, startTracking, stopTracking, filterPoint } from '@/services/location';
import { totalRouteDistance } from '@/services/geo';
import { calcAvgPaceSecPerKm, calcSplits } from '@/services/pace';
import { saveRun } from '@/services/storage';
import { reportProgress } from '@/services/groupRun';

export type RecorderStatus = 'idle' | 'requesting-permission' | 'recording' | 'paused' | 'finished';

interface GroupContext {
  code: string;
  uid: string;
}

export function useRunRecorder(userId: string, groupContext?: GroupContext) {
  const [status, setStatus] = useState<RecorderStatus>('idle');
  const [route, setRoute] = useState<GeoPoint[]>([]);
  const [distanceMeters, setDistanceMeters] = useState(0);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);

  const startTimeRef = useRef<number | null>(null);
  const pausedAccumRef = useRef(0);
  const pauseStartRef = useRef<number | null>(null);
  const routeRef = useRef<GeoPoint[]>([]);
  const tickRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    const unsub = onLocationPoint((point) => {
      if (status !== 'recording') return;
      if (!filterPoint(routeRef.current, point)) return;

      routeRef.current = [...routeRef.current, point];
      setRoute(routeRef.current);
      const dist = totalRouteDistance(routeRef.current);
      setDistanceMeters(dist);

      if (groupContext) {
        const elapsed = elapsedSecondsNow();
        const pace = calcAvgPaceSecPerKm(dist, elapsed);
        reportProgress(groupContext.code, groupContext.uid, dist, pace).catch(() => {});
      }
    });
    return unsub;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status]);

  function elapsedSecondsNow(): number {
    if (!startTimeRef.current) return 0;
    const now = Date.now();
    return (now - startTimeRef.current - pausedAccumRef.current) / 1000;
  }

  useEffect(() => {
    if (status === 'recording') {
      tickRef.current = setInterval(() => setElapsedSeconds(elapsedSecondsNow()), 1000);
    } else if (tickRef.current) {
      clearInterval(tickRef.current);
      tickRef.current = null;
    }
    return () => {
      if (tickRef.current) clearInterval(tickRef.current);
    };
  }, [status]);

  const start = useCallback(async () => {
    setStatus('requesting-permission');
    const granted = await requestLocationPermissions();
    if (!granted) {
      setStatus('idle');
      throw new Error('Location permission denied');
    }
    routeRef.current = [];
    setRoute([]);
    setDistanceMeters(0);
    setElapsedSeconds(0);
    pausedAccumRef.current = 0;
    startTimeRef.current = Date.now();
    await startTracking();
    setStatus('recording');
  }, []);

  const pause = useCallback(() => {
    pauseStartRef.current = Date.now();
    setStatus('paused');
  }, []);

  const resume = useCallback(() => {
    if (pauseStartRef.current) {
      pausedAccumRef.current += Date.now() - pauseStartRef.current;
      pauseStartRef.current = null;
    }
    setStatus('recording');
  }, []);

  const finish = useCallback(async (): Promise<RunRecord> => {
    await stopTracking();
    setStatus('finished');
    const endedAt = Date.now();
    const startedAt = startTimeRef.current ?? endedAt;
    const durationSeconds = elapsedSecondsNow();
    const dist = totalRouteDistance(routeRef.current);

    const run: RunRecord = {
      id: `${startedAt}-${Math.random().toString(36).slice(2, 8)}`,
      userId,
      startedAt,
      endedAt,
      route: routeRef.current,
      distanceMeters: dist,
      durationSeconds,
      avgPaceSecPerKm: calcAvgPaceSecPerKm(dist, durationSeconds),
      splits: calcSplits(routeRef.current),
    };
    await saveRun(run);
    return run;
  }, [userId]);

  return { status, route, distanceMeters, elapsedSeconds, start, pause, resume, finish };
}
