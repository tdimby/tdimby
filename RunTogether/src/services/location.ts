import * as Location from 'expo-location';
import * as TaskManager from 'expo-task-manager';
import { GeoPoint } from '@/types';
import { isPlausibleJump } from '@/services/geo';

export const LOCATION_TASK_NAME = 'run-together-background-location';

type PointListener = (point: GeoPoint) => void;
const listeners = new Set<PointListener>();

export function onLocationPoint(listener: PointListener): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function toGeoPoint(loc: Location.LocationObject): GeoPoint {
  return {
    latitude: loc.coords.latitude,
    longitude: loc.coords.longitude,
    altitude: loc.coords.altitude,
    speed: loc.coords.speed,
    timestamp: loc.timestamp,
  };
}

try {
  TaskManager.defineTask(LOCATION_TASK_NAME, async ({ data, error }) => {
    if (error) {
      console.warn('Background location task error', error);
      return;
    }
    const { locations } = (data as { locations: Location.LocationObject[] }) ?? { locations: [] };
    for (const loc of locations ?? []) {
      const point = toGeoPoint(loc);
      listeners.forEach((l) => l(point));
    }
  });
} catch (err) {
  // Defining the background task can fail in some Expo Go / bare-client combinations;
  // don't let it crash the whole app at bundle-evaluation time. Foreground tracking
  // (used while the Run screen is open) doesn't depend on this task being registered.
  console.warn('Failed to register background location task', err);
}

let foregroundSubscription: Location.LocationSubscription | null = null;

/**
 * Requires foreground permission to track at all. Background permission is
 * requested too, but its absence (or failure — e.g. running inside Expo Go,
 * which can't provide a custom Info.plist for background-location entitlements)
 * only disables background tracking, not the whole feature: the run still
 * records while the Run screen is open in the foreground.
 */
export async function requestLocationPermissions(): Promise<boolean> {
  const fg = await Location.requestForegroundPermissionsAsync();
  if (fg.status !== 'granted') return false;

  try {
    await Location.requestBackgroundPermissionsAsync();
  } catch (err) {
    console.warn('Background location permission unavailable; foreground-only tracking', err);
  }
  return true;
}

export async function startTracking(): Promise<void> {
  try {
    const hasStarted = await Location.hasStartedLocationUpdatesAsync(LOCATION_TASK_NAME);
    if (hasStarted) return;

    await Location.startLocationUpdatesAsync(LOCATION_TASK_NAME, {
      accuracy: Location.Accuracy.BestForNavigation,
      timeInterval: 2000,
      distanceInterval: 5,
      showsBackgroundLocationIndicator: true,
      foregroundService: {
        notificationTitle: 'RunTogether is tracking your run',
        notificationBody: 'Recording your pace, route, and distance.',
      },
      pausesUpdatesAutomatically: false,
    });
  } catch (err) {
    // No background-location entitlement available (e.g. Expo Go). Fall back to
    // foreground-only tracking: it still records the run while this screen is open.
    console.warn('Background tracking unavailable, using foreground-only tracking', err);
    foregroundSubscription = await Location.watchPositionAsync(
      {
        accuracy: Location.Accuracy.BestForNavigation,
        timeInterval: 2000,
        distanceInterval: 5,
      },
      (loc) => {
        const point = toGeoPoint(loc);
        listeners.forEach((l) => l(point));
      }
    );
  }
}

export async function stopTracking(): Promise<void> {
  if (foregroundSubscription) {
    foregroundSubscription.remove();
    foregroundSubscription = null;
  }
  const hasStarted = await Location.hasStartedLocationUpdatesAsync(LOCATION_TASK_NAME);
  if (hasStarted) {
    await Location.stopLocationUpdatesAsync(LOCATION_TASK_NAME);
  }
}

/** Filters a raw GPS point against the last accepted point to reject noisy jumps. */
export function filterPoint(route: GeoPoint[], point: GeoPoint): boolean {
  const last = route[route.length - 1];
  if (!last) return true;
  return isPlausibleJump(last, point);
}
