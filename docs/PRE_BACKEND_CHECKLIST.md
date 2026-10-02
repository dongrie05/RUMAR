# Checklist antes do Supabase

Esta fase corre sem projeto Supabase, sem chaves Google e sem Hermes ligado.
Serve para validar comportamento, dados e interface com serviços simulados.

## Contratos locais concluídos

- `AppConfig` lê URLs/chaves apenas por `--dart-define`.
- `AgentGateway` define o mesmo contrato para API real e mock local.
- `MockAgentService` simula fila e resultado da IA.
- `JobValidation` valida descrição, cliente, zona, duração e data.
- `agent_service.dart` está pronto para o gateway Edge Function.

## Fluxos a testar manualmente

- Criar trabalho válido.
- Tentar guardar trabalho sem descrição, zona, cliente ou com duração inválida.
- Editar trabalho e impedir datas passadas.
- Alterar estado para confirmado e concluído.
- Criar lembrete, cancelar lembrete e adicionar ao calendário.
- Abrir a página de materiais, orçamentos e preferências.
- Usar a app sem internet e confirmar que os dados locais continuam disponíveis.
- Executar pedido ao mock da IA e apresentar o rascunho antes de qualquer confirmação.
- Redimensionar para iPhone pequeno, Android médio, tablet e browser.

## Testes automatizados

Executar dentro de `mobile/`:

```bash
flutter test
```

O ambiente local deve ter um Flutter SDK com cache de engine gravável. Se o
SDK global estiver protegido pelo macOS, usar uma instalação do Flutter no
ambiente de desenvolvimento ou corrigir as permissões do SDK antes da análise.

## Critério de entrada no backend

Só avançar para o Supabase quando:

- os testes locais passarem;
- todos os fluxos principais tiverem estado vazio/loading/erro;
- o mock da IA tiver o mesmo formato esperado pelo gateway real;
- não existir nenhum segredo ou URL de produção hardcoded;
- for possível explicar a um profissional o que acontece quando a IA falha.
