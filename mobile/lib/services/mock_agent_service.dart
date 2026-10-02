import 'agent_service.dart';

/// Deterministic local assistant used before Supabase/Hermes is configured.
/// It exercises the same queue-shaped contract as the real gateway.
class MockAgentService implements AgentGateway {
  int _sequence = 0;
  final Map<String, AgentJobResult> _results = {};

  @override
  Future<AgentJob> enqueue({
    required String accessToken,
    required String kind,
    required Map<String, dynamic> input,
  }) async {
    final id = 'local-agent-${++_sequence}';
    _results[id] = AgentJobResult(
      status: 'succeeded',
      text: _buildResponse(kind, input),
    );
    return AgentJob(id: id, kind: kind, status: 'queued');
  }

  @override
  Future<AgentJobResult> readResult({
    required String supabaseRestUrl,
    required String accessToken,
    required String anonKey,
    required String jobId,
  }) async =>
      _results[jobId] ??
      const AgentJobResult(
        status: 'failed',
        error: 'Tarefa local não encontrada.',
      );

  String _buildResponse(String kind, Map<String, dynamic> input) {
    final text = (input['text'] ?? input['message'] ?? '').toString().trim();
    if (text.isEmpty) {
      return 'Descreve o trabalho para eu preparar um rascunho.';
    }
    if (kind == 'daily_plan') {
      return 'Plano preparado. Confirma a ordem sugerida antes de alterar a agenda.';
    }
    return 'Rascunho preparado a partir de: “$text”. Confirma os detalhes antes de guardar.';
  }
}
