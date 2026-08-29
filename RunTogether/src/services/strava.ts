import * as AuthSession from 'expo-auth-session';
import * as WebBrowser from 'expo-web-browser';
import * as SecureStore from 'expo-secure-store';
import * as FileSystem from 'expo-file-system';
import { RunRecord } from '@/types';

WebBrowser.maybeCompleteAuthSession();

const STRAVA_CLIENT_ID = process.env.EXPO_PUBLIC_STRAVA_CLIENT_ID ?? '';
const STRAVA_CLIENT_SECRET = process.env.EXPO_PUBLIC_STRAVA_CLIENT_SECRET ?? '';

const AUTH_ENDPOINT = 'https://www.strava.com/oauth/mobile/authorize';
const TOKEN_ENDPOINT = 'https://www.strava.com/oauth/token';
const UPLOAD_ENDPOINT = 'https://www.strava.com/api/v3/uploads';

const TOKEN_STORE_KEY = 'runtogether:strava_tokens';

interface StravaTokens {
  accessToken: string;
  refreshToken: string;
  expiresAt: number; // epoch seconds
}

async function saveTokens(tokens: StravaTokens): Promise<void> {
  await SecureStore.setItemAsync(TOKEN_STORE_KEY, JSON.stringify(tokens));
}

export async function getStoredTokens(): Promise<StravaTokens | null> {
  const raw = await SecureStore.getItemAsync(TOKEN_STORE_KEY);
  return raw ? (JSON.parse(raw) as StravaTokens) : null;
}

export async function disconnectStrava(): Promise<void> {
  await SecureStore.deleteItemAsync(TOKEN_STORE_KEY);
}

/**
 * Launches Strava's OAuth consent screen and exchanges the returned code for tokens.
 * Requires EXPO_PUBLIC_STRAVA_CLIENT_ID / _SECRET, and the app's redirect URI
 * ("runtogether://strava-auth") to be registered in the Strava API application settings.
 */
export async function connectStrava(): Promise<boolean> {
  const redirectUri = AuthSession.makeRedirectUri({ scheme: 'runtogether', path: 'strava-auth' });

  const request = new AuthSession.AuthRequest({
    clientId: STRAVA_CLIENT_ID,
    redirectUri,
    responseType: AuthSession.ResponseType.Code,
    usePKCE: false, // Strava's OAuth flow doesn't support PKCE; the confidential client_secret is used instead
    scopes: ['activity:write', 'activity:read_all'],
    extraParams: { approval_prompt: 'auto' },
  });

  const result = await request.promptAsync({ authorizationEndpoint: AUTH_ENDPOINT });
  if (result.type !== 'success' || !result.params?.code) {
    return false;
  }

  const tokenRes = await fetch(TOKEN_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: STRAVA_CLIENT_ID,
      client_secret: STRAVA_CLIENT_SECRET,
      code: result.params.code,
      grant_type: 'authorization_code',
    }),
  });
  if (!tokenRes.ok) return false;
  const json = await tokenRes.json();

  await saveTokens({
    accessToken: json.access_token,
    refreshToken: json.refresh_token,
    expiresAt: json.expires_at,
  });
  return true;
}

async function getValidAccessToken(): Promise<string | null> {
  const tokens = await getStoredTokens();
  if (!tokens) return null;

  const nowSeconds = Date.now() / 1000;
  if (tokens.expiresAt - nowSeconds > 60) {
    return tokens.accessToken;
  }

  const res = await fetch(TOKEN_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: STRAVA_CLIENT_ID,
      client_secret: STRAVA_CLIENT_SECRET,
      refresh_token: tokens.refreshToken,
      grant_type: 'refresh_token',
    }),
  });
  if (!res.ok) return null;
  const json = await res.json();
  await saveTokens({
    accessToken: json.access_token,
    refreshToken: json.refresh_token,
    expiresAt: json.expires_at,
  });
  return json.access_token;
}

/** Builds a minimal GPX 1.1 file from a run's route so it can be uploaded to Strava. */
export function buildGpx(run: RunRecord): string {
  const points = run.route
    .map((p) => {
      const time = new Date(p.timestamp).toISOString();
      return `      <trkpt lat="${p.latitude}" lon="${p.longitude}"><time>${time}</time></trkpt>`;
    })
    .join('\n');

  return `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="RunTogether" xmlns="http://www.topografix.com/GPX/1/1">
  <trk>
    <name>RunTogether Run</name>
    <trkseg>
${points}
    </trkseg>
  </trk>
</gpx>`;
}

/** Uploads a completed run to Strava as an activity. Returns the Strava upload id, or null on failure. */
export async function uploadRunToStrava(run: RunRecord): Promise<string | null> {
  const accessToken = await getValidAccessToken();
  if (!accessToken) throw new Error('Not connected to Strava');

  const gpx = buildGpx(run);
  const fileUri = `${FileSystem.cacheDirectory}run-${run.id}.gpx`;
  await FileSystem.writeAsStringAsync(fileUri, gpx, { encoding: FileSystem.EncodingType.UTF8 });

  const form = new FormData();
  form.append('file', {
    uri: fileUri,
    name: `run-${run.id}.gpx`,
    type: 'application/gpx+xml',
  } as unknown as Blob);
  form.append('data_type', 'gpx');
  form.append('name', `Run ${new Date(run.startedAt).toLocaleDateString()}`);
  form.append('trainer', '0');
  form.append('commute', '0');

  const res = await fetch(UPLOAD_ENDPOINT, {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}` },
    body: form,
  });
  if (!res.ok) return null;
  const json = await res.json();
  return json.id?.toString() ?? null;
}
