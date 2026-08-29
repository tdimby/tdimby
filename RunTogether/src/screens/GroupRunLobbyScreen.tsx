import React, { useEffect, useState } from 'react';
import { View, Text, TextInput, Pressable, StyleSheet, FlatList, Alert } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import type { RootStackParamList } from '@/navigation/RootNavigator';
import { useAuth } from '@/context/AuthContext';
import { createGroupRun, joinGroupRun, startGroupRun, subscribeToGroupRun } from '@/services/groupRun';
import { GroupRun } from '@/types';

type Props = NativeStackScreenProps<RootStackParamList, 'GroupRunLobby'>;

export default function GroupRunLobbyScreen({ navigation }: Props) {
  const { user } = useAuth();
  const [joinCode, setJoinCode] = useState('');
  const [name, setName] = useState(user?.displayName ?? 'Runner');
  const [roomCode, setRoomCode] = useState<string | null>(null);
  const [activeRun, setActiveRun] = useState<GroupRun | null>(null);

  useEffect(() => {
    if (!roomCode) return;
    const unsub = subscribeToGroupRun(roomCode, (run) => {
      setActiveRun(run);
      if (run?.status === 'active') {
        navigation.replace('Run', { groupCode: run.code });
      }
    });
    return unsub;
  }, [roomCode]);

  async function handleCreate() {
    if (!user) return;
    const run = await createGroupRun(user.uid, name);
    setActiveRun(run);
    setRoomCode(run.code);
  }

  async function handleJoin() {
    if (!user || !joinCode.trim()) return;
    try {
      const code = joinCode.trim().toUpperCase();
      await joinGroupRun(code, user.uid, name);
      setRoomCode(code);
    } catch (err) {
      Alert.alert('Could not join', 'Check the code and try again.');
    }
  }

  async function handleStart() {
    if (!activeRun) return;
    await startGroupRun(activeRun.code);
  }

  if (activeRun) {
    const isHost = activeRun.hostUid === user?.uid;
    return (
      <View style={styles.container}>
        <Text style={styles.codeLabel}>Room code</Text>
        <Text style={styles.code}>{activeRun.code}</Text>
        <Text style={styles.hint}>Share this code with friends so they can join.</Text>

        <Text style={styles.sectionTitle}>Runners</Text>
        <FlatList
          data={Object.values(activeRun.participants)}
          keyExtractor={(p) => p.uid}
          renderItem={({ item }) => <Text style={styles.participant}>• {item.displayName}</Text>}
        />

        {isHost ? (
          <Pressable style={styles.startButton} onPress={handleStart}>
            <Text style={styles.buttonText}>Start Run for Everyone</Text>
          </Pressable>
        ) : (
          <Text style={styles.hint}>Waiting for the host to start the run…</Text>
        )}
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text style={styles.label}>Your name</Text>
      <TextInput style={styles.input} value={name} onChangeText={setName} placeholder="Your name" />

      <Pressable style={styles.primaryButton} onPress={handleCreate}>
        <Text style={styles.buttonText}>Create a Group Run</Text>
      </Pressable>

      <Text style={styles.orText}>— or —</Text>

      <TextInput
        style={styles.input}
        value={joinCode}
        onChangeText={setJoinCode}
        placeholder="Enter room code"
        autoCapitalize="characters"
      />
      <Pressable style={styles.secondaryButton} onPress={handleJoin}>
        <Text style={styles.buttonText}>Join</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 24, gap: 12 },
  label: { fontSize: 14, color: '#555' },
  input: { borderWidth: 1, borderColor: '#ddd', borderRadius: 10, padding: 14, fontSize: 16 },
  primaryButton: { backgroundColor: '#FC4C02', paddingVertical: 16, borderRadius: 14, alignItems: 'center', marginTop: 8 },
  secondaryButton: { backgroundColor: '#1E1E1E', paddingVertical: 16, borderRadius: 14, alignItems: 'center' },
  buttonText: { color: 'white', fontWeight: '700', fontSize: 16 },
  orText: { textAlign: 'center', color: '#999', marginVertical: 4 },
  codeLabel: { textAlign: 'center', color: '#888', marginTop: 20 },
  code: { textAlign: 'center', fontSize: 48, fontWeight: '800', letterSpacing: 6 },
  hint: { textAlign: 'center', color: '#888', marginTop: 4 },
  sectionTitle: { fontSize: 16, fontWeight: '700', marginTop: 24 },
  participant: { fontSize: 16, paddingVertical: 6 },
  startButton: { backgroundColor: '#FC4C02', paddingVertical: 16, borderRadius: 14, alignItems: 'center', marginTop: 'auto' },
});
