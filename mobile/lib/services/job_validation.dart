import '../main.dart';

class JobValidation {
  const JobValidation._();

  static String? validate(Job job, {DateTime? now}) {
    if (job.title.trim().length < 3) {
      return 'A descrição precisa de mais detalhe.';
    }
    // Rascunhos podem começar sem cliente ou morada. The app deliberately
    // uses “Novo cliente”/“A confirmar” until the professional completes them.
    if (job.client.trim().isEmpty) {
      return 'Indica o cliente ou deixa um rascunho.';
    }
    if (job.location.trim().isEmpty) {
      return 'Indica a zona ou deixa um rascunho.';
    }
    if (job.durationMinutes < 15 || job.durationMinutes > 24 * 60) {
      return 'A duração deve estar entre 15 minutos e 24 horas.';
    }
    if (job.scheduledAt != null &&
        job.scheduledAt!.isBefore(
          (now ?? DateTime.now()).subtract(const Duration(minutes: 1)),
        )) {
      return 'A visita não pode ficar agendada no passado.';
    }
    return null;
  }
}
