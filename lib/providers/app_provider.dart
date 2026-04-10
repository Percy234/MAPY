import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider đơn giản để quản lý app state
final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier();
});

class AppState {
  final String appVersion;
  final bool isDarkMode;
  final bool isInitialized;

  AppState({
    this.appVersion = '1.0.0',
    this.isDarkMode = false,
    this.isInitialized = false,
  });

  AppState copyWith({
    String? appVersion,
    bool? isDarkMode,
    bool? isInitialized,
  }) {
    return AppState(
      appVersion: appVersion ?? this.appVersion,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier() : super(AppState());

  void toggleDarkMode() {
    state = state.copyWith(isDarkMode: !state.isDarkMode);
  }

  void setInitialized(bool isInitialized) {
    state = state.copyWith(isInitialized: isInitialized);
  }
}
