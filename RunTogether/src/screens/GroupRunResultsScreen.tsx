import React from 'react';
import { View, Text, FlatList, StyleSheet, Pressable } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import type { RootStackParamList } from '@/navigation/RootNavigator';
import { leaderboard } from '@/services/groupRun';
import { formatDuration } from '@/services/pace';

type Props = NativeStackScreenProps<RootStackParamList, 'GroupRunResults'>;

export default function GroupRunResultsScreen({ route, navigation }: Props) {
  const board = leaderboard(route.params.run);
  const leaderDistance = board[0]?.distanceMeters ?? 0;
  const leaderTime = board[0]?.finishTimeSeconds;

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Final Results</Text>
      <FlatList
        data={board}
        keyExtractor={(p) => p.uid}
        contentContainerStyle={{ padding: 16 }}
        renderItem={({ item, index }) => {
          const behindMeters = leaderDistance - item.distanceMeters;
          const behindTime =
            item.finishTimeSeconds != null && leaderTime != null ? item.finishTimeSeconds - leaderTime : null;
          return (
            <View style={styles.row}>
              <Text style={styles.place}>{index + 1}</Text>
              <View style={{ flex: 1 }}>
                <Text style={styles.name}>{item.displayName}</Text>
                <Text style={styles.detail}>
                  {(item.distanceMeters / 1000).toFixed(2)} km
                  {item.finished && item.finishTimeSeconds != null
                    ? ` · ${formatDuration(item.finishTimeSeconds)}`
                    : ' · did not finish'}
                </Text>
              </View>
              {index === 0 ? (
                <Text style={styles.leaderTag}>LEADER</Text>
              ) : (
                <Text style={styles.gapTag}>
                  {behindTime != null ? `+${formatDuration(behindTime)}` : `-${behindMeters.toFixed(0)}m`}
                </Text>
              )}
            </View>
          );
        }}
      />
      <Pressable style={styles.doneButton} onPress={() => navigation.popToTop()}>
        <Text style={styles.doneText}>Done</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  title: { fontSize: 22, fontWeight: '800', textAlign: 'center', marginTop: 16 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 14,
    marginBottom: 10,
    gap: 12,
  },
  place: { fontSize: 20, fontWeight: '800', width: 28, textAlign: 'center', color: '#888' },
  name: { fontSize: 16, fontWeight: '700' },
  detail: { fontSize: 13, color: '#888' },
  leaderTag: { color: '#FC4C02', fontWeight: '800', fontSize: 12 },
  gapTag: { color: '#666', fontWeight: '700' },
  doneButton: { padding: 18, alignItems: 'center' },
  doneText: { color: '#666', fontWeight: '600' },
});
