import React, { useEffect, useState } from 'react';
import { View, Text, Pressable, StyleSheet, TextInput, Alert } from 'react-native';
import { useAuth } from '@/context/AuthContext';
import { connectStrava, disconnectStrava, getStoredTokens } from '@/services/strava';

export default function SettingsScreen() {
  const { user, setDisplayName } = useAuth();
  const [name, setName] = useState(user?.displayName ?? '');
  const [stravaConnected, setStravaConnected] = useState(false);

  useEffect(() => {
    getStoredTokens().then((t) => setStravaConnected(!!t));
  }, []);

  async function handleConnectStrava() {
    try {
      const ok = await connectStrava();
      setStravaConnected(ok);
      if (!ok) Alert.alert('Strava connection cancelled or failed.');
    } catch (err: any) {
      Alert.alert('Strava error', err?.message ?? 'Could not connect to Strava.');
    }
  }

  async function handleDisconnectStrava() {
    await disconnectStrava();
    setStravaConnected(false);
  }

  return (
    <View style={styles.container}>
      <Text style={styles.label}>Display name</Text>
      <TextInput style={styles.input} value={name} onChangeText={setName} onBlur={() => setDisplayName(name)} />

      <Text style={styles.sectionTitle}>Strava</Text>
      {stravaConnected ? (
        <Pressable style={styles.dangerButton} onPress={handleDisconnectStrava}>
          <Text style={styles.buttonText}>Disconnect Strava</Text>
        </Pressable>
      ) : (
        <Pressable style={styles.stravaButton} onPress={handleConnectStrava}>
          <Text style={styles.buttonText}>Connect Strava</Text>
        </Pressable>
      )}
      <Text style={styles.hint}>
        Connecting lets you upload finished runs to Strava from the run summary screen.
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 24, gap: 12 },
  label: { fontSize: 14, color: '#555' },
  input: { borderWidth: 1, borderColor: '#ddd', borderRadius: 10, padding: 14, fontSize: 16 },
  sectionTitle: { fontSize: 16, fontWeight: '700', marginTop: 24 },
  stravaButton: { backgroundColor: '#FC4C02', paddingVertical: 16, borderRadius: 14, alignItems: 'center' },
  dangerButton: { backgroundColor: '#B00020', paddingVertical: 16, borderRadius: 14, alignItems: 'center' },
  buttonText: { color: 'white', fontWeight: '700', fontSize: 16 },
  hint: { color: '#888', fontSize: 13, marginTop: 4 },
});
