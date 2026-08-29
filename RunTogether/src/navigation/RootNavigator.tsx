import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import HomeScreen from '@/screens/HomeScreen';
import RunScreen from '@/screens/RunScreen';
import RunSummaryScreen from '@/screens/RunSummaryScreen';
import HistoryScreen from '@/screens/HistoryScreen';
import GroupRunLobbyScreen from '@/screens/GroupRunLobbyScreen';
import GroupRunLiveScreen from '@/screens/GroupRunLiveScreen';
import GroupRunResultsScreen from '@/screens/GroupRunResultsScreen';
import SettingsScreen from '@/screens/SettingsScreen';
import { RunRecord, GroupRun } from '@/types';

export type RootStackParamList = {
  Home: undefined;
  Run: { groupCode?: string } | undefined;
  RunSummary: { run: RunRecord };
  History: undefined;
  GroupRunLobby: undefined;
  GroupRunLive: { code: string };
  GroupRunResults: { run: GroupRun };
  Settings: undefined;
};

const Stack = createNativeStackNavigator<RootStackParamList>();

export default function RootNavigator() {
  return (
    <NavigationContainer>
      <Stack.Navigator initialRouteName="Home" screenOptions={{ headerTitleAlign: 'center' }}>
        <Stack.Screen name="Home" component={HomeScreen} options={{ title: 'RunTogether' }} />
        <Stack.Screen name="Run" component={RunScreen} options={{ title: 'Run' }} />
        <Stack.Screen name="RunSummary" component={RunSummaryScreen} options={{ title: 'Run Summary' }} />
        <Stack.Screen name="History" component={HistoryScreen} options={{ title: 'History' }} />
        <Stack.Screen name="GroupRunLobby" component={GroupRunLobbyScreen} options={{ title: 'Run with Friends' }} />
        <Stack.Screen name="GroupRunLive" component={GroupRunLiveScreen} options={{ title: 'Live Run' }} />
        <Stack.Screen name="GroupRunResults" component={GroupRunResultsScreen} options={{ title: 'Results' }} />
        <Stack.Screen name="Settings" component={SettingsScreen} options={{ title: 'Settings' }} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
