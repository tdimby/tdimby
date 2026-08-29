export interface GeoPoint {
  latitude: number;
  longitude: number;
  altitude?: number | null;
  timestamp: number; // ms epoch
  speed?: number | null; // m/s, from GPS if available
}

export interface RunRecord {
  id: string;
  userId: string;
  startedAt: number;
  endedAt: number;
  route: GeoPoint[];
  distanceMeters: number;
  durationSeconds: number;
  avgPaceSecPerKm: number; // seconds per km
  splits: Split[];
  splitUnit: 'km' | 'mi';
  stravaActivityId?: string;
}

export interface Split {
  index: number;
  splitSeconds: number;
  cumulativeSeconds: number;
}

export interface UserProfile {
  uid: string;
  displayName: string;
  photoURL?: string;
  stravaConnected: boolean;
}

export interface GroupRunParticipant {
  uid: string;
  displayName: string;
  distanceMeters: number;
  lastUpdated: number;
  paceSecPerKm: number;
  finished: boolean;
  finishTimeSeconds?: number;
}

export interface GroupRun {
  id: string;
  code: string;
  hostUid: string;
  status: 'lobby' | 'active' | 'finished';
  startedAt?: number;
  createdAt: number;
  participants: Record<string, GroupRunParticipant>;
}

/** How far ahead/behind a participant is versus another, at the same elapsed time. */
export interface Gap {
  uid: string;
  meters: number; // positive = ahead of the reference runner
  seconds: number; // estimated time gap, positive = ahead
}
