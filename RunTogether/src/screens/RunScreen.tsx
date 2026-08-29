import React, { useEffect } from 'react';
import { View, Text, Pressable, StyleSheet, Alert } from 'react-native';
import MapView, { Polyline } from 'react-native-maps';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import type { RootStackParamList } from '@/navigation/RootNavigator';
import { useAuth } from '@/context/AuthContext';
import { useRunRecorder } from '@/hooks/useRunRecorder';
import { calcAvgPaceSecPerKm, formatDuration, formatPace } from '@/services/pace';
import { finishParticipant } from '@/services/groupRun';

type Props = NativeStackScreenProps<RootStackParamList, 'Run'>;

export default function RunScreen({ navigation, route }: Props) {
  const { user } = useAuth();
  const groupCode = route.params?.groupCode;
  const recorder = useRunRecorder(user?.uid ?? 'anonymous', groupCode && user ? { code: groupCode, uid: user.uid } : undefined);

  useEffect(() => {
    recorder.start().catch((err) => {
      Alert.alert('Location permission needed', err.message ?? 'Please allow location access to record a run.');
      navigation.goBack();
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const pace = calcAvgPaceSecPerKm(recorder.distanceMeters, recorder.elapsedSeconds);
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

      <View style={styles.stats}>
        <View style={styles.statBlock}>
          <Text style={styles.statValue}>{(recorder.distanceMeters / 1000).toFixed(2)}</Text>
          <Text style={styles.statLabel}>km</Text>
        </View>
        <View style={styles.statBlock}>
          <Text style={styles.statValue}>{formatDuration(recorder.elapsedSeconds)}</Text>
          <Text style={styles.statLabel}>time</Text>
        </View>
        <View style={styles.statBlock}>
          <Text style={styles.statValue}>{formatPace(pace)}</Text>
          <Text style={styles.statLabel}>pace</Text>
        </View>
      </View>

      <View style={styles.controls}>
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
  stats: { flexDirection: 'row', justifyContent: 'space-around', paddingVertical: 20, backgroundColor: 'white' },
  statBlock: { alignItems: 'center' },
  statValue: { fontSize: 28, fontWeight: '800' },
  statLabel: { fontSize: 13, color: '#888' },
  controls: { flexDirection: 'row', gap: 12, padding: 16, backgroundColor: 'white' },
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
