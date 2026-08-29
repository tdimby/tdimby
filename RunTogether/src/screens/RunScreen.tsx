import React, { useEffect } from 'react';
import { View, Text, Pressable, StyleSheet, Alert } from 'react-native';
import MapView, { Polyline } from 'react-native-maps';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import type { RootStackParamList } from '@/navigation/RootNavigator';
import { useAuth } from '@/context/AuthContext';
import { useSettings } from '@/context/SettingsContext';
import { useRunRecorder } from '@/hooks/useRunRecorder';
import { calcAvgPaceSecPerKm, formatDistance, formatDuration, formatPace, paceForUnit } from '@/services/pace';
import { finishParticipant } from '@/services/groupRun';

type Props = NativeStackScreenProps<RootStackParamList, 'Run'>;

export default function RunScreen({ navigation, route }: Props) {
  const { user } = useAuth();
  const { unit, autoPauseEnabled } = useSettings();
  const groupCode = route.params?.groupCode;
  const recorder = useRunRecorder(
    user?.uid ?? 'anonymous',
    unit,
    autoPauseEnabled,
    groupCode && user ? { code: groupCode, uid: user.uid } : undefined
  );

  useEffect(() => {
    recorder.prepare().catch((err) => {
      Alert.alert('Location permission needed', err.message ?? 'Please allow location access to record a run.');
      navigation.goBack();
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    // Group runs start together the moment the host starts the run — no separate tap needed.
    if (recorder.status === 'ready' && groupCode) {
      recorder.start();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [recorder.status, groupCode]);

  const paceSecPerKm = calcAvgPaceSecPerKm(recorder.distanceMeters, recorder.elapsedSeconds);
  const lastPoint = recorder.route[recorder.route.length - 1];

  async function handleFinish() {
    const run = await recorder.finish();
    if (groupCode && user) {
      await finishParticipant(groupCode, user.uid, run.durationSeconds);
    }
    navigation.replace('RunSummary', { run });
  }

  return (
    <View style={styles.container}>
      <MapView
        style={styles.map}
        showsUserLocation
        followsUserLocation
        initialRegion={
          lastPoint
            ? { latitude: lastPoint.latitude, longitude: lastPoint.longitude, latitudeDelta: 0.01, longitudeDelta: 0.01 }
            : undefined
        }
      >
        {recorder.route.length > 1 && (
          <Polyline
            coordinates={recorder.route.map((p) => ({ latitude: p.latitude, longitude: p.longitude }))}
            strokeWidth={4}
            strokeColor="#FC4C02"
          />
        )}
      </MapView>

      {recorder.isAutoPaused && (
        <View style={styles.autoPauseBadge}>
          <Text style={styles.autoPauseText}>Auto-paused — resumes when you start moving</Text>
        </View>
      )}

      <View style={styles.stats}>
        <View style={styles.statBlock}>
          <Text style={styles.statValue}>{formatDistance(recorder.distanceMeters, unit).split(' ')[0]}</Text>
          <Text style={styles.statLabel}>{unit}</Text>
        </View>
        <View style={styles.statBlock}>
          <Text style={styles.statValue}>{formatDuration(recorder.elapsedSeconds)}</Text>
          <Text style={styles.statLabel}>time</Text>
        </View>
        <View style={styles.statBlock}>
          <Text style={styles.statValue}>{formatPace(paceForUnit(paceSecPerKm, unit), unit)}</Text>
          <Text style={styles.statLabel}>pace</Text>
        </View>
      </View>

      <View style={styles.controls}>
        {recorder.status === 'ready' && !groupCode ? (
          <Pressable style={styles.startButton} onPress={recorder.start}>
            <Text style={styles.controlText}>Start Run</Text>
          </Pressable>
        ) : (
          <>
            {recorder.status === 'recording' ? (
              <Pressable style={styles.pauseButton} onPress={recorder.pause}>
                <Text style={styles.controlText}>Pause</Text>
              </Pressable>
            ) : (
              <Pressable style={styles.pauseButton} onPress={recorder.resume}>
                <Text style={styles.controlText}>Resume</Text>
              </Pressable>
            )}
            <Pressable style={styles.finishButton} onPress={handleFinish}>
              <Text style={styles.controlText}>Finish</Text>
            </Pressable>
          </>
        )}
      </View>

      {groupCode && (
        <Pressable
          style={styles.friendsButton}
          onPress={() => navigation.navigate('GroupRunLive', { code: groupCode })}
        >
          <Text style={styles.friendsButtonText}>Friends' Pace ▲▼</Text>
        </Pressable>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  map: { flex: 1 },
  autoPauseBadge: {
    position: 'absolute',
    bottom: 140,
    alignSelf: 'center',
    backgroundColor: '#B00020',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 20,
  },
  autoPauseText: { color: 'white', fontWeight: '700', fontSize: 13 },
  stats: { flexDirection: 'row', justifyContent: 'space-around', paddingVertical: 20, backgroundColor: 'white' },
  statBlock: { alignItems: 'center' },
  statValue: { fontSize: 28, fontWeight: '800' },
  statLabel: { fontSize: 13, color: '#888' },
  controls: { flexDirection: 'row', gap: 12, padding: 16, backgroundColor: 'white' },
  startButton: { flex: 1, backgroundColor: '#FC4C02', paddingVertical: 16, borderRadius: 14, alignItems: 'center' },
  pauseButton: { flex: 1, backgroundColor: '#1E1E1E', paddingVertical: 16, borderRadius: 14, alignItems: 'center' },
  finishButton: { flex: 1, backgroundColor: '#FC4C02', paddingVertical: 16, borderRadius: 14, alignItems: 'center' },
  controlText: { color: 'white', fontWeight: '700', fontSize: 16 },
  friendsButton: {
    position: 'absolute',
    top: 16,
    alignSelf: 'center',
    backgroundColor: '#111',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 20,
  },
  friendsButtonText: { color: 'white', fontWeight: '700' },
});
