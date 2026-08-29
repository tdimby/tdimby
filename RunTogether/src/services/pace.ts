import { GeoPoint, Split } from '@/types';
import { haversineMeters } from '@/services/geo';
import { DistanceUnit } from '@/context/SettingsContext';

const METERS_PER_MILE = 1609.344;

export function unitMeters(unit: DistanceUnit): number {
  return unit === 'mi' ? METERS_PER_MILE : 1000;
}

export function unitLabel(unit: DistanceUnit): string {
  return unit === 'mi' ? 'mi' : 'km';
}

/** Canonical average pace in seconds per kilometer, for storage. Returns 0 for no distance covered. */
export function calcAvgPaceSecPerKm(distanceMeters: number, durationSeconds: number): number {
  if (distanceMeters <= 0) return 0;
  return durationSeconds / (distanceMeters / 1000);
}

/** Converts a canonical seconds-per-km pace into seconds-per-unit for display. */
export function paceForUnit(secPerKm: number, unit: DistanceUnit): number {
  if (unit === 'mi') return secPerKm * (METERS_PER_MILE / 1000);
  return secPerKm;
}

export function formatDistance(distanceMeters: number, unit: DistanceUnit): string {
  const value = distanceMeters / unitMeters(unit);
  return `${value.toFixed(2)} ${unitLabel(unit)}`;
}

/** Expects a pace already converted to the given unit (see paceForUnit). */
export function formatPace(secPerUnit: number, unit: DistanceUnit): string {
  if (!isFinite(secPerUnit) || secPerUnit <= 0) return '--:--';
  const min = Math.floor(secPerUnit / 60);
  const sec = Math.round(secPerUnit % 60);
  return `${min}:${sec.toString().padStart(2, '0')} /${unitLabel(unit)}`;
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

/** Computes per-unit-distance splits (km or mile) from a recorded route. */
export function calcSplits(route: GeoPoint[], unit: DistanceUnit): Split[] {
  const splits: Split[] = [];
  if (route.length < 2) return splits;

  const splitDistance = unitMeters(unit);
  const startTime = route[0].timestamp;
  let cumulativeDist = 0;
  let nextSplitAt = splitDistance;
  let lastSplitTime = startTime;
  let index = 1;

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
        index,
        splitSeconds: (splitTime - lastSplitTime) / 1000,
        cumulativeSeconds: (splitTime - startTime) / 1000,
      });

      lastSplitTime = splitTime;
      cumulativeDist += neededDist;
      remaining -= neededDist;
      segStart = { ...segStart, timestamp: splitTime };
      nextSplitAt += splitDistance;
      index += 1;
    }
    cumulativeDist += remaining;
  }

  return splits;
}
