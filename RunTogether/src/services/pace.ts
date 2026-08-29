import { GeoPoint, Split } from '@/types';
import { haversineMeters } from '@/services/geo';

/** Average pace in seconds per kilometer. Returns 0 for no distance covered. */
export function calcAvgPaceSecPerKm(distanceMeters: number, durationSeconds: number): number {
  if (distanceMeters <= 0) return 0;
  const km = distanceMeters / 1000;
  return durationSeconds / km;
}

export function formatPace(secPerKm: number): string {
  if (!isFinite(secPerKm) || secPerKm <= 0) return '--:--';
  const min = Math.floor(secPerKm / 60);
  const sec = Math.round(secPerKm % 60);
  return `${min}:${sec.toString().padStart(2, '0')} /km`;
}

export function formatDuration(totalSeconds: number): string {
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = Math.floor(totalSeconds % 60);
  if (h > 0) {
    return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }
  return `${m}:${s.toString().padStart(2, '0')}`;
}

/** Computes per-km splits from a recorded route. */
export function calcSplits(route: GeoPoint[]): Split[] {
  const splits: Split[] = [];
  if (route.length < 2) return splits;

  const startTime = route[0].timestamp;
  let cumulativeDist = 0;
  let nextSplitAt = 1000; // meters
  let lastSplitTime = startTime;
  let kmCount = 1;

  for (let i = 1; i < route.length; i++) {
    const prev = route[i - 1];
    const curr = route[i];
    const segDist = haversineMeters(prev, curr);
    let remaining = segDist;
    let segStart = prev;

    while (cumulativeDist + remaining >= nextSplitAt) {
      const neededDist = nextSplitAt - cumulativeDist;
      const frac = remaining > 0 ? neededDist / remaining : 0;
      const segDuration = curr.timestamp - segStart.timestamp;
      const splitTime = segStart.timestamp + segDuration * frac;

      splits.push({
        km: kmCount,
        splitSeconds: (splitTime - lastSplitTime) / 1000,
        cumulativeSeconds: (splitTime - startTime) / 1000,
      });

      lastSplitTime = splitTime;
      cumulativeDist += neededDist;
      remaining -= neededDist;
      segStart = { ...segStart, timestamp: splitTime };
      nextSplitAt += 1000;
      kmCount += 1;
    }
    cumulativeDist += remaining;
  }

  return splits;
}
