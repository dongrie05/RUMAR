import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client for the queue-based Agent Gateway. The app sends a small request and
/// polls its job; Hermes remains private on the Mac mini.
class AgentJob {
  const AgentJob({required this.id, required this.kind, required this.status});

  final String id;
  final String kind;
  final String status;

  factory AgentJob.fromJson(Map<String, dynamic> json) => AgentJob(
    id: json['id'] as String,
    kind: json['kind'] as String? ?? 'assistant_request',
    status: json['status'] as String? ?? 'queued',
  );
}

class AgentJobResult {
  const AgentJobResult({required this.status, this.text, this.error});

  final String status;
  final String? text;
  final String? error;

  bool get isFinished =>
      status == 'succeeded' || status == 'failed' || status == 'cancelled';
}

abstract interface class AgentGateway {
  Future<AgentJob> enqueue({
    required String accessToken,
    required String kind,
    required Map<String, dynamic> input,
  });

  Future<AgentJobResult> readResult({
    required String supabaseRestUrl,
    required String accessToken,
    required String anonKey,
    required String jobId,
  });
}

class AgentService implements AgentGateway {
  AgentService({http.Client? client, required this.gatewayUrl, String? anonKey})
    : _client = client ?? http.Client(),
      anonKey = anonKey ?? const String.fromEnvironment('SUPABASE_ANON_KEY');

  final http.Client _client;
  final String gatewayUrl;
  final String anonKey;

  @override
  Future<AgentJob> enqueue({
    required String accessToken,
    required String kind,
    required Map<String, dynamic> input,
  }) async {
    final response = await _client.post(
      Uri.parse(gatewayUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        if (anonKey.isNotEmpty) 'apikey': anonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'kind': kind, 'input': input}),
    );
    if (response.statusCode != 202) {
      throw Exception('Não foi possível iniciar o assistente.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return AgentJob.fromJson(body['job'] as Map<String, dynamic>);
  }

  @override
  Future<AgentJobResult> readResult({
    required String supabaseRestUrl,
    required String accessToken,
    required String anonKey,
    required String jobId,
  }) async {
    final response = await _client.get(
      Uri.parse(
        '$supabaseRestUrl/agent_jobs?id=eq.$jobId&select=status,result,error',
      ),
      headers: {'Authorization': 'Bearer $accessToken', 'apikey': anonKey},
    );
    if (response.statusCode != 200) {
      throw Exception('Não foi possível consultar o assistente.');
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    if (rows.isEmpty) throw Exception('Tarefa do assistente não encontrada.');
    final row = rows.first as Map<String, dynamic>;
    final result = row['result'] as Map<String, dynamic>?;
    return AgentJobResult(
      status: row['status'] as String? ?? 'queued',
      text: result?['text'] as String?,
      error: row['error'] as String?,
    );
  }
}
