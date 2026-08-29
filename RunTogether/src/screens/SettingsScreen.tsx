import React, { useEffect, useState } from 'react';
import { View, Text, Pressable, StyleSheet, TextInput, Alert, Switch } from 'react-native';
import { useAuth } from '@/context/AuthContext';
import { useSettings } from '@/context/SettingsContext';
import { connectStrava, disconnectStrava, getStoredTokens } from '@/services/strava';

export default function SettingsScreen() {
  const { user, setDisplayName } = useAuth();
  const { unit, setUnit, autoPauseEnabled, setAutoPauseEnabled } = useSettings();
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

      <Text style={styles.sectionTitle}>Units</Text>
      <View style={styles.unitToggle}>
        <Pressable
          style={[styles.unitOption, unit === 'km' && styles.unitOptionActive]}
          onPress={() => setUnit('km')}
        >
          <Text style={[styles.unitOptionText, unit === 'km' && styles.unitOptionTextActive]}>Kilometers</Text>
        </Pressable>
        <Pressable
          style={[styles.unitOption, unit === 'mi' && styles.unitOptionActive]}
          onPress={() => setUnit('mi')}
        >
          <Text style={[styles.unitOptionText, unit === 'mi' && styles.unitOptionTextActive]}>Miles</Text>
        </Pressable>
      </View>

      <Text style={styles.sectionTitle}>Tracking</Text>
      <View style={styles.switchRow}>
        <View style={{ flex: 1 }}>
          <Text style={styles.switchLabel}>Auto-pause</Text>
          <Text style={styles.hint}>Automatically pauses when you stop moving, resumes when you start again.</Text>
        </View>
        <Switch value={autoPauseEnabled} onValueChange={setAutoPauseEnabled} />
      </View>

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
  unitToggle: { flexDirection: 'row', gap: 8 },
  unitOption: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#ddd',
    alignItems: 'center',
  },
  unitOptionActive: { backgroundColor: '#FC4C02', borderColor: '#FC4C02' },
  unitOptionText: { fontWeight: '600', color: '#444' },
  unitOptionTextActive: { color: 'white' },
  switchRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  switchLabel: { fontSize: 15, fontWeight: '600' },
  stravaButton: { backgroundColor: '#FC4C02', paddingVertical: 16, borderRadius: 14, alignItems: 'center' },
  dangerButton: { backgroundColor: '#B00020', paddingVertical: 16, borderRadius: 14, alignItems: 'center' },
  buttonText: { color: 'white', fontWeight: '700', fontSize: 16 },
  hint: { color: '#888', fontSize: 13, marginTop: 4 },
});
