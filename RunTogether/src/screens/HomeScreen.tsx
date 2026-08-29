import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import type { RootStackParamList } from '@/navigation/RootNavigator';

type Props = NativeStackScreenProps<RootStackParamList, 'Home'>;

export default function HomeScreen({ navigation }: Props) {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>RunTogether</Text>
      <Text style={styles.subtitle}>Track your pace. Race your friends. Sync to Strava.</Text>

      <Pressable style={[styles.button, styles.primary]} onPress={() => navigation.navigate('Run')}>
        <Text style={styles.buttonText}>Start Solo Run</Text>
      </Pressable>

      <Pressable style={[styles.button, styles.accent]} onPress={() => navigation.navigate('GroupRunLobby')}>
        <Text style={styles.buttonText}>Run with Friends</Text>
      </Pressable>

      <Pressable style={styles.button} onPress={() => navigation.navigate('History')}>
        <Text style={styles.buttonTextSecondary}>Run History</Text>
      </Pressable>

      <Pressable style={styles.button} onPress={() => navigation.navigate('Settings')}>
        <Text style={styles.buttonTextSecondary}>Settings & Strava</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 24, gap: 12 },
  title: { fontSize: 32, fontWeight: '800', textAlign: 'center' },
  subtitle: { fontSize: 15, color: '#666', textAlign: 'center', marginBottom: 24 },
  button: { paddingVertical: 16, borderRadius: 14, alignItems: 'center', marginTop: 8 },
  primary: { backgroundColor: '#FC4C02' },
  accent: { backgroundColor: '#1E1E1E' },
  buttonText: { color: 'white', fontSize: 17, fontWeight: '700' },
  buttonTextSecondary: { color: '#1E1E1E', fontSize: 15, fontWeight: '600' },
});
