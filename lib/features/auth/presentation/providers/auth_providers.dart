import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/auth_service.dart';

/// Se as credenciais foram configuradas via --dart-define.
final supabaseConfiguredProvider = Provider<bool>((ref) {
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  return url.isNotEmpty && key.isNotEmpty;
});

/// Cliente Supabase (null se não configurado).
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});

/// AuthService (null se Supabase não configurado).
final authServiceProvider = Provider<AuthService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return AuthService(client);
});

/// Stream de usuário logado (null = anônimo).
final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(authServiceProvider);
  if (auth == null) return Stream<User?>.value(null);

  return auth.onAuthStateChange
      .map((state) => state.session?.user)
      .asBroadcastStream();
});

/// Usuário atual (nullable).
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).asData?.value;
});

/// Está logado?
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});