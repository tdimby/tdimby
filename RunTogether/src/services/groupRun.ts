import {
  doc,
  setDoc,
  updateDoc,
  onSnapshot,
  collection,
  query,
  where,
  getDocs,
  serverTimestamp,
  Unsubscribe,
} from 'firebase/firestore';
import { db } from '@/firebase';
import { GroupRun, GroupRunParticipant, Gap } from '@/types';

function randomCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let out = '';
  for (let i = 0; i < 5; i++) out += chars[Math.floor(Math.random() * chars.length)];
  return out;
}

export async function createGroupRun(hostUid: string, hostName: string): Promise<GroupRun> {
  const code = randomCode();
  const id = code;
  const groupRun: GroupRun = {
    id,
    code,
    hostUid,
    status: 'lobby',
    createdAt: Date.now(),
    participants: {
      [hostUid]: {
        uid: hostUid,
        displayName: hostName,
        distanceMeters: 0,
        lastUpdated: Date.now(),
        paceSecPerKm: 0,
        finished: false,
      },
    },
  };
  await setDoc(doc(db, 'groupRuns', id), groupRun);
  return groupRun;
}

export async function joinGroupRun(code: string, uid: string, displayName: string): Promise<void> {
  const participant: GroupRunParticipant = {
    uid,
    displayName,
    distanceMeters: 0,
    lastUpdated: Date.now(),
    paceSecPerKm: 0,
    finished: false,
  };
  await updateDoc(doc(db, 'groupRuns', code), {
    [`participants.${uid}`]: participant,
  });
}

export async function startGroupRun(code: string): Promise<void> {
  await updateDoc(doc(db, 'groupRuns', code), {
    status: 'active',
    startedAt: Date.now(),
  });
}

export async function finishParticipant(code: string, uid: string, finishTimeSeconds: number): Promise<void> {
  await updateDoc(doc(db, 'groupRuns', code), {
    [`participants.${uid}.finished`]: true,
    [`participants.${uid}.finishTimeSeconds`]: finishTimeSeconds,
  });
}

/** Called on every GPS update during an active group run: pushes this runner's live progress. */
export async function reportProgress(
  code: string,
  uid: string,
  distanceMeters: number,
  paceSecPerKm: number
): Promise<void> {
  await updateDoc(doc(db, 'groupRuns', code), {
    [`participants.${uid}.distanceMeters`]: distanceMeters,
    [`participants.${uid}.paceSecPerKm`]: paceSecPerKm,
    [`participants.${uid}.lastUpdated`]: Date.now(),
  });
}

export function subscribeToGroupRun(code: string, cb: (run: GroupRun | null) => void): Unsubscribe {
  return onSnapshot(doc(db, 'groupRuns', code), (snap) => {
    cb(snap.exists() ? (snap.data() as GroupRun) : null);
  });
}

/**
 * Computes how far ahead/behind each participant is relative to `meUid`, based on
 * distance covered so far. Positive meters/seconds = that participant is ahead.
 * The time gap is estimated using the reference runner's own current pace.
 */
export function computeGaps(run: GroupRun, meUid: string): Gap[] {
  const me = run.participants[meUid];
  if (!me) return [];

  const paceSecPerMeter = me.paceSecPerKm > 0 ? me.paceSecPerKm / 1000 : 0;

  return Object.values(run.participants)
    .filter((p) => p.uid !== meUid)
    .map((p) => {
      const meters = p.distanceMeters - me.distanceMeters;
      const seconds = paceSecPerMeter > 0 ? meters * paceSecPerMeter : 0;
      return { uid: p.uid, meters, seconds };
    })
    .sort((a, b) => b.meters - a.meters);
}

/** Final leaderboard ordered by finish time (finishers first, fastest first), then distance. */
export function leaderboard(run: GroupRun): GroupRunParticipant[] {
  return Object.values(run.participants).sort((a, b) => {
    if (a.finished && b.finished) {
      return (a.finishTimeSeconds ?? Infinity) - (b.finishTimeSeconds ?? Infinity);
    }
    if (a.finished !== b.finished) return a.finished ? -1 : 1;
    return b.distanceMeters - a.distanceMeters;
  });
}
