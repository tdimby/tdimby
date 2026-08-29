import React, { useEffect, useState } from 'react';
import { View, Text, FlatList, StyleSheet } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import type { RootStackParamList } from '@/navigation/RootNavigator';
import { useAuth } from '@/context/AuthContext';
import { GroupRun } from '@/types';
import { subscribeToGroupRun, computeGaps } from '@/services/groupRun';
import { formatDuration, formatPace } from '@/services/pace';

type Props = NativeStackScreenProps<RootStackParamList, 'GroupRunLive'>;

/**
 * A live "ahead/behind" leaderboard overlay for a group run. Meant to be shown
 * alongside (or instead of) the map during an active run — each row is a friend,
 * with how far ahead or behind them the current runner is, updated in real time.
 */
export default function GroupRunLiveScreen({ route, navigation }: Props) {
  const { user } = useAuth();
  const [run, setRun] = useState<GroupRun | null>(null);

  useEffect(() => {
    const unsub = subscribeToGroupRun(route.params.code, (r) => {
      setRun(r);
      if (r?.status === 'finished') {
        navigation.replace('GroupRunResults', { run: r });
      }
    });
    return unsub;
  }, [route.params.code]);

  if (!run || !user) return null;

  const gaps = computeGaps(run, user.uid);
  const me = run.participants[user.uid];

  return (
    <View style={styles.container}>
      <View style={styles.meCard}>
        <Text style={styles.meDistance}>{((me?.distanceMeters ?? 0) / 1000).toFixed(2)} km</Text>
        <Text style={styles.mePace}>{formatPace(me?.paceSecPerKm ?? 0)}</Text>
      </View>

      <FlatList
        data={gaps}
        keyExtractor={(g) => g.uid}
        contentContainerStyle={{ padding: 16 }}
        renderItem={({ item }) => {
          const p = run.participants[item.uid];
          const ahead = item.meters > 0;
          return (
            <View style={styles.row}>
              <Text style={styles.name}>{p.displayName}</Text>
              <Text style={[styles.gap, ahead ? styles.aheadText : styles.behindText]}>
                {ahead ? '▲' : '▼'} {Math.abs(item.meters).toFixed(0)}m
                {item.seconds ? ` (${ahead ? '-' : '+'}${formatDuration(Math.abs(item.seconds))})` : ''}
              </Text>
            </View>
          );
        }}
        ListEmptyComponent={<Text style={styles.muted}>Waiting for friends to start moving…</Text>}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#111' },
  meCard: { padding: 24, alignItems: 'center', borderBottomWidth: 1, borderColor: '#333' },
  meDistance: { color: 'white', fontSize: 40, fontWeight: '800' },
  mePace: { color: '#aaa', fontSize: 16, marginTop: 4 },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#1c1c1c',
    borderRadius: 12,
    padding: 16,
    marginBottom: 10,
  },
  name: { color: 'white', fontSize: 16, fontWeight: '600' },
  gap: { fontSize: 16, fontWeight: '700' },
  aheadText: { color: '#4CD964' },
  behindText: { color: '#FF3B30' },
  muted: { color: '#777', textAlign: 'center', marginTop: 20 },
});
