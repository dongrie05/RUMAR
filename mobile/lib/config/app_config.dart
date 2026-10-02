class AppConfig {
  const AppConfig({
    required this.agentGatewayUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  /// Build with --dart-define; no credentials are committed to the app.
  factory AppConfig.fromEnvironment() => const AppConfig(
    agentGatewayUrl: String.fromEnvironment('AGENT_GATEWAY_URL'),
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  final String agentGatewayUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get hasBackend => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  bool get hasAgent => agentGatewayUrl.isNotEmpty && hasBackend;
}
