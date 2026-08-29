const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);

// Firebase's JS SDK ships a "react-native" package-export condition, but Metro's
// package-exports resolution (Expo's default) doesn't reliably pick it, and instead
// resolves firebase/auth to a build that doesn't auto-register the auth component —
// causing "Component auth has not been registered yet" at runtime. Disabling
// package-exports resolution falls back to the legacy "main"/"react-native" field
// resolution, which firebase supports correctly for React Native.
config.resolver.unstable_enablePackageExports = false;
config.resolver.sourceExts.push('cjs');

module.exports = config;
