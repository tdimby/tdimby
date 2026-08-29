import React, { useMemo, useState } from 'react';
import { View, Text, Pressable, StyleSheet, ScrollView, Alert } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import type { RootStackParamList } from '@/navigation/RootNavigator';
import { useSettings } from '@/context/SettingsContext';
import { calcSplits, formatDistance, formatDuration, formatPace, paceForUnit, unitLabel } from '@/services/pace';
import { uploadRunToStrava, getStoredTokens } from '@/services/strava';
import { updateRun } from '@/services/storage';

type Props = NativeStackScreenProps<RootStackParamList, 'RunSummary'>;

export default function RunSummaryScreen({ route, navigation }: Props) {
  const { run } = route.params;
  const { unit } = useSettings();
  const [uploading, setUploading] = useState(false);
  const [uploaded, setUploaded] = useState(!!run.stravaActivityId);

  const splits = useMemo(() => calcSplits(run.route, unit), [run.route, unit]);

  async function handleUploadToStrava() {
    setUploading(true);
    try {
      const tokens = await getStoredTokens();
      if (!tokens) {
        Alert.alert('Connect Strava first', 'Go to Settings to link your Strava account.');
        return;
      }
      const uploadId = await uploadRunToStrava(run);
      if (uploadId) {
        await updateRun(run.id, { stravaActivityId: uploadId });
        setUploaded(true);
        Alert.alert('Sent to Strava', 'Your run is processing on Strava and will appear shortly.');
      } else {
        Alert.alert('Upload failed', 'Could not upload this run to Strava. Try again later.');
      }
    } catch (err: any) {
      Alert.alert('Upload failed', err?.message ?? 'Unknown error');
    } finally {
      setUploading(false);
    }
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.big}>{formatDistance(run.distanceMeters, unit)}</Text>
      <View style={styles.row}>
        <Stat label="Duration" value={formatDuration(run.durationSeconds)} />
        <Stat label="Avg Pace" value={formatPace(paceForUnit(run.avgPaceSecPerKm, unit), unit)} />
      </View>

      <Text style={styles.sectionTitle}>Splits</Text>
      {splits.map((s) => (
        <View key={s.index} style={styles.splitRow}>
          <Text style={styles.splitLabel}>
            {unitLabel(unit) === 'mi' ? 'Mi' : 'Km'} {s.index}
          </Text>
          <Text style={styles.splitValue}>{formatPace(s.splitSeconds, unit)}</Text>
        </View>
      ))}
      {splits.length === 0 && (
        <Text style={styles.muted}>Run under 1 {unitLabel(unit)} — no splits recorded.</Text>
      )}

      <Pressable
        style={[styles.stravaButton, uploaded && styles.stravaButtonDone]}
        onPress={handleUploadToStrava}
        disabled={uploading || uploaded}
      >
        <Text style={styles.stravaText}>
          {uploaded ? 'Uploaded to Strava ✓' : uploading ? 'Uploading…' : 'Upload to Strava'}
        </Text>
      </Pressable>

      <Pressable style={styles.doneButton} onPress={() => navigation.popToTop()}>
        <Text style={styles.doneText}>Done</Text>
      </Pressable>
    </ScrollView>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.statBlock}>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 24, gap: 12 },
  big: { fontSize: 44, fontWeight: '800', textAlign: 'center' },
  row: { flexDirection: 'row', justifyContent: 'space-around', marginVertical: 16 },
  statBlock: { alignItems: 'center' },
  statValue: { fontSize: 22, fontWeight: '700' },
  statLabel: { fontSize: 13, color: '#888' },
  sectionTitle: { fontSize: 17, fontWeight: '700', marginTop: 8 },
  splitRow: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 6, borderBottomWidth: 1, borderColor: '#eee' },
  splitLabel: { color: '#444' },
  splitValue: { fontWeight: '600' },
  muted: { color: '#999', fontStyle: 'italic' },
  stravaButton: { backgroundColor: '#FC4C02', paddingVertical: 16, borderRadius: 14, alignItems: 'center', marginTop: 24 },
  stravaButtonDone: { backgroundColor: '#999' },
  stravaText: { color: 'white', fontWeight: '700', fontSize: 16 },
  doneButton: { paddingVertical: 14, alignItems: 'center' },
  doneText: { color: '#666', fontWeight: '600' },
});
