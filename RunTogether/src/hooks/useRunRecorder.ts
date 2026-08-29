import { useCallback, useEffect, useRef, useState } from 'react';
import { GeoPoint, RunRecord } from '@/types';
import { onLocationPoint, requestLocationPermissions, startTracking, stopTracking, filterPoint } from '@/services/location';
import { totalRouteDistance, haversineMeters } from '@/services/geo';
import { calcAvgPaceSecPerKm, calcSplits } from '@/services/pace';
import { saveRun } from '@/services/storage';
import { reportProgress } from '@/services/groupRun';
import { DistanceUnit } from '@/context/SettingsContext';

export type RecorderStatus = 'idle' | 'requesting-permission' | 'ready' | 'recording' | 'paused' | 'finished';

interface GroupContext {
  code: string;
  uid: string;
}

// Auto-pause: below this speed we consider the runner stopped.
const STATIONARY_SPEED_MPS = 0.6; // ~2.2 km/h, comfortably below a walking pace
const AUTO_PAUSE_AFTER_MS = 10_000;

export function useRunRecorder(
  userId: string,
  unit: DistanceUnit,
  autoPauseEnabled: boolean,
  groupContext?: GroupContext
) {
  const [status, setStatus] = useState<RecorderStatus>('idle');
  const [route, setRoute] = useState<GeoPoint[]>([]);
  const [distanceMeters, setDistanceMeters] = useState(0);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [isAutoPaused, setIsAutoPaused] = useState(false);

  const statusRef = useRef<RecorderStatus>('idle');
  const startTimeRef = useRef<number | null>(null);
  const pausedAccumRef = useRef(0);
  const pauseStartRef = useRef<number | null>(null);
  const routeRef = useRef<GeoPoint[]>([]);
  const tickRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const lastMovingAtRef = useRef<number>(0);
  const lastPointRef = useRef<GeoPoint | null>(null);

  useEffect(() => {
    statusRef.current = status;
  }, [status]);

  function elapsedSecondsNow(): number {
    if (!startTimeRef.current) return 0;
    const now = Date.now();
    return (now - startTimeRef.current - pausedAccumRef.current) / 1000;
  }

  function resumeFromPause() {
    if (pauseStartRef.current) {
      pausedAccumRef.current += Date.now() - pauseStartRef.current;
      pauseStartRef.current = null;
    }
    setIsAutoPaused(false);
    setStatus('recording');
  }

  useEffect(() => {
    const unsub = onLocationPoint((point) => {
      const current = statusRef.current;
      if (current !== 'recording' && current !== 'paused') return;

      // Estimate instantaneous speed: prefer the GPS-reported value, else derive it.
      let speed = point.speed ?? null;
      if (speed == null && lastPointRef.current) {
        const dtSeconds = (point.timestamp - lastPointRef.current.timestamp) / 1000;
        speed = dtSeconds > 0 ? haversineMeters(lastPointRef.current, point) / dtSeconds : 0;
      }
      lastPointRef.current = point;

      const isMoving = (speed ?? 0) > STATIONARY_SPEED_MPS;
      if (isMoving) lastMovingAtRef.current = point.timestamp;

      if (current === 'recording' && autoPauseEnabled) {
        const stationaryFor = point.timestamp - (lastMovingAtRef.current || point.timestamp);
        if (stationaryFor >= AUTO_PAUSE_AFTER_MS) {
          pauseStartRef.current = Date.now();
          setIsAutoPaused(true);
          setStatus('paused');
          return;
        }
      }

      if (current === 'paused') {
        if (isAutoPaused && isMoving) resumeFromPause();
        return;
      }

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
  }, [autoPauseEnabled, isAutoPaused]);

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

  /** Requests permission and starts GPS tracking, but doesn't begin recording distance/time yet. */
  const prepare = useCallback(async () => {
    setStatus('requesting-permission');
    const granted = await requestLocationPermissions();
    if (!granted) {
      setStatus('idle');
      throw new Error('Location permission denied');
    }
    routeRef.current = [];
    lastPointRef.current = null;
    setRoute([]);
    setDistanceMeters(0);
    setElapsedSeconds(0);
    pausedAccumRef.current = 0;
    await startTracking();
    setStatus('ready');
  }, []);

  /** Begins recording distance/time from now. Call after prepare(). */
  const start = useCallback(() => {
    startTimeRef.current = Date.now();
    lastMovingAtRef.current = Date.now();
    setStatus('recording');
  }, []);

  const pause = useCallback(() => {
    pauseStartRef.current = Date.now();
    setIsAutoPaused(false);
    setStatus('paused');
  }, []);

  const resume = useCallback(() => {
    resumeFromPause();
    // eslint-disable-next-line react-hooks/exhaustive-deps
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
      splits: calcSplits(routeRef.current, unit),
      splitUnit: unit,
    };
    await saveRun(run);
    return run;
  }, [userId, unit]);

  return {
    status,
    route,
    distanceMeters,
    elapsedSeconds,
    isAutoPaused,
    prepare,
    start,
    pause,
    resume,
    finish,
  };
}
