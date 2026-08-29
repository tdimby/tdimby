import React, { useCallback, useState } from 'react';
import { View, Text, FlatList, Pressable, StyleSheet } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import type { RootStackParamList } from '@/navigation/RootNavigator';
import { RunRecord } from '@/types';
import { getRuns } from '@/services/storage';
import { formatDuration, formatPace } from '@/services/pace';

type Props = NativeStackScreenProps<RootStackParamList, 'History'>;

export default function HistoryScreen({ navigation }: Props) {
  const [runs, setRuns] = useState<RunRecord[]>([]);

  useFocusEffect(
    useCallback(() => {
      getRuns().then(setRuns);
    }, [])
  );

  return (
    <FlatList
      data={runs}
      keyExtractor={(r) => r.id}
      contentContainerStyle={{ padding: 16 }}
      ListEmptyComponent={<Text style={styles.empty}>No runs yet. Go run!</Text>}
      renderItem={({ item }) => (
        <Pressable style={styles.card} onPress={() => navigation.navigate('RunSummary', { run: item })}>
          <Text style={styles.date}>{new Date(item.startedAt).toLocaleString()}</Text>
          <View style={styles.row}>
            <Text style={styles.distance}>{(item.distanceMeters / 1000).toFixed(2)} km</Text>
            <Text style={styles.meta}>{formatDuration(item.durationSeconds)}</Text>
            <Text style={styles.meta}>{formatPace(item.avgPaceSecPerKm)}</Text>
          </View>
          {item.stravaActivityId && <Text style={styles.stravaBadge}>Synced to Strava</Text>}
        </Pressable>
      )}
    />
  );
}

const styles = StyleSheet.create({
  empty: { textAlign: 'center', marginTop: 40, color: '#999' },
  card: { backgroundColor: 'white', borderRadius: 14, padding: 16, marginBottom: 12, elevation: 1 },
  date: { color: '#888', fontSize: 12, marginBottom: 6 },
  row: { flexDirection: 'row', justifyContent: 'space-between' },
  distance: { fontSize: 20, fontWeight: '800' },
  meta: { fontSize: 15, color: '#444', alignSelf: 'center' },
  stravaBadge: { color: '#FC4C02', fontSize: 12, fontWeight: '700', marginTop: 8 },
});
