import { GeoPoint } from '@/types';

const EARTH_RADIUS_M = 6371000;

/** Great-circle distance between two points, in meters. */
export function haversineMeters(
  a: { latitude: number; longitude: number },
  b: { latitude: number; longitude: number }
): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(b.latitude - a.latitude);
  const dLon = toRad(b.longitude - a.longitude);
  const lat1 = toRad(a.latitude);
  const lat2 = toRad(b.latitude);

  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
  return EARTH_RADIUS_M * c;
}

/** Drop GPS jitter: ignore jumps that imply an unrealistic speed (> 10 m/s ~ elite sprint pace). */
export function isPlausibleJump(prev: GeoPoint, next: GeoPoint, maxSpeedMs = 10): boolean {
  const dtSeconds = (next.timestamp - prev.timestamp) / 1000;
  if (dtSeconds <= 0) return false;
  const distance = haversineMeters(prev, next);
  const impliedSpeed = distance / dtSeconds;
  return impliedSpeed <= maxSpeedMs;
}

export function totalRouteDistance(route: GeoPoint[]): number {
  let total = 0;
  for (let i = 1; i < route.length; i++) {
    total += haversineMeters(route[i - 1], route[i]);
  }
  return total;
}

/** Distance covered along the route by a given elapsed time (ms since route start). Interpolates within the bracketing segment. */
export function distanceAtElapsedMs(route: GeoPoint[], elapsedMs: number): number {
  if (route.length === 0) return 0;
  const startTime = route[0].timestamp;
  const targetTime = startTime + elapsedMs;
  let cumulative = 0;

  for (let i = 1; i < route.length; i++) {
    const prev = route[i - 1];
    const curr = route[i];
    const segDist = haversineMeters(prev, curr);
    if (curr.timestamp >= targetTime) {
      const segDuration = curr.timestamp - prev.timestamp;
      if (segDuration <= 0) return cumulative;
      const frac = (targetTime - prev.timestamp) / segDuration;
      return cumulative + segDist * Math.max(0, Math.min(1, frac));
    }
    cumulative += segDist;
  }
  return cumulative;
}
