import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:mobile/services/agent_service.dart';
import 'package:mobile/services/job_validation.dart';
import 'package:mobile/services/mock_agent_service.dart';

void main() {
  test('valida um trabalho completo', () {
    final job = Job(
      title: 'Trocar quadro elétrico',
      client: 'Carla Mendes',
      location: 'Odivelas',
      time: '09:00',
      status: 'Rascunho',
      kind: 'Novo',
      durationMinutes: 90,
      scheduledAt: DateTime.now().add(const Duration(hours: 2)),
    );

    expect(JobValidation.validate(job), isNull);
  });

  test('rejeita duração inválida e trabalho no passado', () {
    final job = Job(
      title: 'Quadro',
      client: 'Carla',
      location: 'Lisboa',
      time: '08:00',
      status: 'Rascunho',
      kind: 'Novo',
      durationMinutes: 5,
      scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
    );

    expect(JobValidation.validate(job), isNotNull);
  });

  test('mock da IA respeita o contrato do gateway', () async {
    final gateway = MockAgentService();
    final job = await gateway.enqueue(
      accessToken: 'local',
      kind: 'assistant_request',
      input: {'text': 'trocar tomadas amanhã em Benfica'},
    );
    expect(job.status, 'queued');

    final result = await gateway.readResult(
      supabaseRestUrl: '',
      accessToken: 'local',
      anonKey: 'local',
      jobId: job.id,
    );
    expect(result.status, 'succeeded');
    expect(result.text, contains('tomadas'));
  });

  test('estado de resultado identifica conclusão', () {
    expect(const AgentJobResult(status: 'running').isFinished, isFalse);
    expect(const AgentJobResult(status: 'succeeded').isFinished, isTrue);
    expect(const AgentJobResult(status: 'failed').isFinished, isTrue);
  });
}
