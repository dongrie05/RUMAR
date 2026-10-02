# Plano de produto, piloto e IA

_Versão de trabalho — 7 de agosto de 2026. Valores em USD/EUR são estimativas sem IVA; confirmar no momento de contratar._

## Decisão de produto

O produto não é um CRM genérico para obras. É o sistema de operação diária de um profissional de instalações: transforma pedidos em trabalhos organizados, reduz chamadas/mensagens esquecidas e torna o dia mais rentável através da agenda, rota e seguimento.

O piloto não deve tentar provar que conseguimos construir todas as integrações. Deve provar quatro coisas:

1. O profissional abre a app todos os dias.
2. Regista e conclui trabalhos mais depressa do que com notas/WhatsApp.
3. A agenda e os lembretes evitam esquecimentos.
4. A IA poupa tempo real e é suficientemente fiável para ser usada novamente.

Meta do piloto: 5 profissionais independentes (eletricistas e canalizadores), 4 semanas de utilização real, pelo menos 3 utilizações semanais por pessoa e pelo menos 2 funcionalidades que cada utilizador diga que manteria se a app passasse a ser paga.

## O que já existe no repositório

### App Flutter

- Interface móvel/web com páginas Hoje, Trabalhos, Clientes, Rota e Mais.
- Criação/edição básica de trabalhos, estados, materiais e orçamentos de demonstração.
- Persistência local de trabalhos em `SharedPreferences`, para que o protótipo funcione offline.
- Lembretes locais com notificações nativas e preferência de antecedência.
- Ação para criar um evento no calendário nativo.
- Navegação responsiva para telemóvel e web.
- Serviço Dart preparado para chamar uma função de cálculo de rota sem expor a chave Google.

### Backend preparado, ainda não ligado

- Esquema SQL inicial para perfis, clientes, trabalhos, materiais, orçamentos e ligação WhatsApp.
- RLS por `owner_id` nas tabelas já desenhadas.
- Edge Function `calculate-route` preparada para a Google Routes API.
- Documento técnico com as decisões de WhatsApp, calendário e rotas.

### O que ainda é demonstrativo

- Não há autenticação nem ligação Flutter–Supabase.
- O estado principal continua local; os dados não sincronizam entre telemóvel e web.
- O cálculo de rota ainda não está ligado ao planeador, não geocodifica moradas e não optimiza a ordem das visitas.
- O interruptor de WhatsApp é visual; não existe Embedded Signup, webhook ou envio real.
- Orçamentos, materiais e clientes ainda não estão totalmente persistidos/relacionados no backend.
- Não existe IA, histórico de ações, observabilidade, controlo de custos, backups operacionais nem ambiente de produção.

## Arquitetura alvo

```text
Flutter iOS / Android / Web
        │ token Supabase
        ▼
Supabase Auth + Postgres + Storage + RLS
        │
        ├── Edge Functions: CRUD protegido, rotas, IA, webhooks
        ├── Job queue / tarefas agendadas
        └── Agent Gateway
                 ├── API de modelo (primeira fase)
                 └── Hermes Worker (quando houver tarefas autónomas)
                         │
                         ├── Google Routes
                         ├── WhatsApp Business Platform
                         ├── Calendário e notificações
                         └── geração de PDF/orçamentos
```

### Regra essencial de segurança

Supabase é a fonte de verdade. O agente não tem acesso direto ao Postgres, à chave `service_role`, às chaves Google ou aos tokens WhatsApp. Apenas pode chamar ferramentas pequenas, tipadas e verificadas pela nossa API.

Cada chamada recebe o `owner_id` obtido do utilizador autenticado; nunca do texto enviado pelo modelo. As ferramentas e as consultas filtram sempre por esse identificador. O RLS reforça a mesma regra na base de dados. A chave de serviço só vive nas funções de servidor e nunca no Flutter.

## Dados e modelo multi-tenant

Antes do piloto, evoluir o esquema atual para organizações, mesmo que inicialmente cada organização tenha só uma pessoa.

### Tabelas a manter/adicionar

| Área | Tabelas | Prioridade |
| --- | --- | --- |
| Identidade | `organizations`, `organization_members`, `profiles` | Antes do piloto |
| Operação | `clients`, `jobs`, `job_visits`, `materials`, `quotes`, `quote_lines` | Antes do piloto |
| Ficheiros | `attachments` + bucket Storage para fotos, recibos e PDFs | Fase inicial |
| Agenda | `availability_rules`, `calendar_links`, `external_event_id` | Antes/início do piloto |
| Rotas | `job_locations`, `route_plans`, `route_stops`, `route_cache` | Antes/início do piloto |
| IA | `agent_runs`, `agent_actions`, `agent_memories`, `agent_threads`, `usage_events` | Antes da IA real |
| Comunicação | `whatsapp_connections`, `message_threads`, `messages`, `webhook_events` | Fase inicial |
| Qualidade | `audit_log`, `feature_flags`, `feedback`, `error_events` | Antes do piloto |

### Campos que não podem faltar

- IDs UUID, `organization_id`, `created_at`, `updated_at` e `deleted_at` quando fizer sentido.
- Estado enumerado e auditável, não texto livre, para trabalhos, orçamentos e mensagens.
- `idempotency_key` em ações que possam repetir por falha de rede: criar marcação, enviar mensagem, criar evento e confirmar orçamento.
- Coordenadas, precisão e origem da geocodificação separadas da morada escrita pelo cliente.
- Fuso horário `Europe/Lisbon` por defeito, mas guardado explicitamente.
- `version` ou `updated_at` para evitar que telemóvel e web se sobreponham silenciosamente.

## MVP obrigatório antes de convidar o primeiro profissional

### 1. Fundamentos de produto

- [ ] Aplicar migrações Supabase e configurar projeto de desenvolvimento/produção separados.
- [ ] Autenticação por email + palavra-passe e recuperação de conta; Apple/Google podem ficar para depois.
- [ ] Onboarding de 3 minutos: nome, profissão, área de trabalho, horário, antecedência de lembrete e dados da empresa.
- [ ] Trocar `LocalWorkspaceStore` por um repositório Supabase com cache local; manter modo offline para criar/alterar e sincronizar quando regressar rede.
- [ ] CRUD real de clientes e trabalhos, com validação de contacto, morada, duração e estado.
- [ ] Pesquisa, filtros e arquivo de trabalhos concluídos.
- [ ] Erros compreensíveis, estado de sincronização e indicador de que o utilizador está offline.
- [ ] Testes do fluxo criar trabalho → agendar → concluir → ver no cliente.

### 2. Agenda e lembretes

- [ ] Vista diária/semana com arrastar ou ação simples para alterar horário.
- [ ] Deteção de conflitos: sobreposição, tempo de deslocação impossível e horário fora da disponibilidade.
- [ ] Notificação local antes do trabalho e botão de ação “a caminho”/“concluído”.
- [ ] Adicionar evento ao calendário nativo a pedido do utilizador.
- [ ] Guardar que o evento foi criado; não prometer sincronização bidirecional ainda.

### 3. Confiança e operação

- [ ] RLS testado por tabela com dois utilizadores de teste.
- [ ] Auditoria de criação, edição, apagamento e ações de IA.
- [ ] Backups e exportação CSV/JSON da conta para não prender o profissional.
- [ ] Política de privacidade, termos, contacto de suporte e fluxo para apagar conta/dados.
- [ ] Crash reporting e analytics de produto sem gravar conteúdo sensível de clientes.
- [ ] Ambiente de produção com variáveis secretas, limites de gasto e alerta de erro.

### 4. Distribuição e qualidade mobile

- [ ] Ícone, nome temporário, bundle ID/package name próprios e ecrã de privacidade/permissões.
- [ ] Testar em pelo menos um iPhone físico e um Android físico, com má rede.
- [ ] Testar notificações em background e alteração de fuso horário/hora de verão.
- [ ] Testar web em Chrome/Safari, mas manter o telemóvel como experiência prioritária.
- [ ] Distribuir pelo TestFlight e Google Play Internal Testing; não publicar publicamente antes do piloto.

## IA: primeira versão útil, não um chat decorativo

### Casos de uso a implementar primeiro

| Capacidade | Entrada | Resultado | Autonomia |
| --- | --- | --- | --- |
| Criar pedido | Texto/voz do profissional | Cliente, tipo de trabalho, urgência, duração sugerida | Rascunho; confirmar |
| Organizar o dia | Trabalhos e disponibilidade | Ordem proposta, conflitos e tempo livre | Sugestão; confirmar alterações |
| Responder ao cliente | Contexto do trabalho | Rascunho de mensagem em PT-PT | Nunca envia sem confirmação |
| Preparar orçamento | Trabalho, materiais e regras de preço | Linhas e total em rascunho | Confirmar antes de guardar/enviar |
| Resumo no fim do dia | Trabalhos concluídos | Pendentes, materiais e seguimentos | Automático, sem ação externa |
| Aprender preferência | Correções repetidas do profissional | Memória privada proposta | Confirmar ou permitir opt-in |

Não implementar no primeiro piloto: agente que envia WhatsApps sozinho, altera marcações confirmadas, decide preços finais, lê todo o calendário, compra materiais, navegação turn-by-turn própria ou uma “memória global” com dados de todos os profissionais.

### Ferramentas iniciais do agente

```text
search_clients(query)
get_jobs(date_range)
create_draft_job(payload)
update_draft_job(id, payload)
find_available_slots(duration, zone)
propose_route(date)
create_quote_draft(job_id, lines)
draft_customer_message(job_id, intent)
schedule_local_reminder(job_id)
save_memory_proposal(fact, confidence, source)
```

Ferramentas com efeito externo ficam atrás de uma aprovação explícita:

```text
confirm_booking
send_whatsapp_message
send_quote
move_confirmed_job
delete_job
```

### Memória correta

1. Dados estruturados do Supabase: trabalhos, clientes e preços; sempre prevalecem.
2. Contexto breve de conversa: últimos turnos relevantes, com limite.
3. Memória privada: preferências do profissional, fonte, confiança, data e botão para apagar/corrigir.
4. Conhecimento coletivo: apenas métricas e padrões agregados/anónimos, depois de consentimento.

Não começar por embeddings. Para cinco profissionais, as preferências cabem em campos estruturados e notas curtas. Adicionar `pgvector` quando existir pesquisa relevante em muitas notas, PDFs/fotos ou historial. Supabase suporta `pgvector`, mas a pesquisa deve ser sempre filtrada por organização/profissional.

### `Agent Gateway`

Criar uma interface própria que permite trocar o motor sem alterar a app:

```text
runAgent(ownerId, request, allowedTools) -> resposta + ações propostas + uso
```

O gateway é responsável por:

- autenticar o utilizador e construir contexto mínimo;
- escolher modelo conforme a tarefa;
- validar JSON e argumentos das ferramentas;
- limitar a 3 chamadas de ferramenta e 2 tentativas por pedido no piloto;
- pedir confirmação de ações externas;
- guardar `agent_run`, tokens, latência, modelo, ferramentas e resultado;
- aplicar limites por profissional/dia e um interruptor global de emergência;
- devolver ao Flutter texto simples e ações explicáveis.

## Modelos e custos de IA

### Recomendação inicial

Usar a Responses API, com `store: false`, ferramentas próprias e saída JSON estrita para qualquer ação. A Responses API é a opção recomendada para novos fluxos com ferramentas e estado; não dependemos de uma conversa longa para guardar memória.

| Tipo de tarefa | Modelo | Configuração inicial | Porque |
| --- | --- | --- | --- |
| Extrair pedido, classificar urgência, rascunho de mensagem, resumo | `gpt-5.6-luna` | `reasoning: none` ou `low`; resposta curta | Volume alto e custo mínimo |
| Agenda, proposta de rota, orçamento com regras e conflito complexo | `gpt-5.6-terra` | `reasoning: low` | Melhor julgamento sem custo de modelo flagship |
| Casos excecionais avaliados, nunca por defeito | `gpt-5.6-sol` | `reasoning: medium` | Só se as avaliações provarem ganho material |

Segundo a tabela oficial atual, por 1M tokens de contexto curto, `luna` custa $0,20 de entrada e $1,20 de saída; `terra`, $2 e $12; `sol`, $5 e $30. Os preços podem mudar, por isso ficam centralizados numa configuração e não no código de interface. [Preços OpenAI](https://developers.openai.com/api/docs/pricing) e [guia de modelos](https://developers.openai.com/api/docs/guides/latest-model).

### Estimativa simples por profissional/mês

Hipótese conservadora: 100 pedidos simples a `luna` (1.500 tokens de entrada + 400 de saída) e 20 pedidos complexos a `terra` com o mesmo volume.

| Elemento | Cálculo aproximado | Custo mensal |
| --- | ---: | ---: |
| 100 pedidos `luna` | 100 × $0,00078 | $0,08 |
| 20 pedidos `terra` | 20 × $0,0078 | $0,16 |
| Margem para retries, contexto e ferramentas | 5–10× durante o piloto | $1–3 por profissional |

O custo que mais cresce não é a inferência básica; é enviar contexto demasiado longo, usar o modelo forte para tudo ou deixar ferramentas entrarem em ciclos. Começar com uma quota generosa mas controlada: 150 pedidos simples e 30 complexos/mês por profissional, limite técnico de $5 por utilizador/mês e limite global de $30 para todo o piloto.

### Regras de redução de custo

- Não enviar histórico inteiro; carregar apenas dados relevantes.
- Nunca pedir à IA para calcular o que SQL/código determinístico consegue calcular.
- Usar saída estruturada e ferramentas curtas, em vez de textos longos.
- Colocar instruções estáveis e descrições de ferramentas numa prefixo reutilizável; medir cache antes de optimizar.
- Registar `input_tokens`, `output_tokens`, `tool_calls`, duração e sucesso por caso de uso.
- Ter fallback: se a IA falhar, a app continua a permitir criar o trabalho manualmente.

## Hermes Agent: onde faz sentido

Hermes não substitui a API de modelo: também precisa de um fornecedor/modelo e de compute. Acrescenta ciclo de ferramentas, sessões, memória e tarefas agendadas. Pode ser chamado por Python ou por endpoint compatível com APIs OpenAI.

### Decisão por fase

| Fase | Decisão | Justificação |
| --- | --- | --- |
| Antes e início do piloto | Não usar Hermes no caminho normal da app | Menos infraestrutura, menos superfície de falha, mais fácil medir cada fluxo |
| Quando 3+ utilizadores pedirem automações repetidas | Introduzir Hermes como worker isolado | Bom para planeamento diário, triagem e seguimentos agendados |
| Depois de produto comprovado | Avaliar Hermes como runtime principal de automações | Só se a manutenção e as avaliações justificarem |

### Como integrar sem lock-in

- O Hermes corre num contentor/serviço privado, nunca no telemóvel e nunca exposto diretamente à internet.
- O Agent Gateway chama Hermes através de um adaptador; o resto do produto continua a conhecer apenas as nossas ferramentas.
- Desativar terminal, ficheiros, browser livre, instalação e envio de mensagens genérico. Expor apenas as ferramentas da lista acima.
- Criar uma instância/execução por tarefa; não partilhar uma instância concorrente entre utilizadores.
- Usar Supabase como memória canónica. Pode desativar a memória interna do Hermes em fluxos de produto e persistir apenas memórias aprovadas na nossa base de dados.
- Definir `max_iterations` baixo (5–8 para automações), timeouts, retries e fila de tarefas.
- Não criar um perfil Hermes permanente por profissional em escala; a separação deve ser lógica no Supabase e no gateway.

Hermes suporta biblioteca Python, ferramentas restringíveis, perfis/memória e fornecedores OpenAI-compatíveis; isso faz dele um bom worker opcional, não uma dependência central do MVP. [Biblioteca Hermes](https://hermes-agent.nousresearch.com/docs/guides/python-library), [ferramentas Hermes](https://hermes-agent.nousresearch.com/docs/user-guide/features/tools) e [fornecedores](https://hermes-agent.nousresearch.com/docs/integrations/providers).

### Custo Hermes

- Software: validar a licença/versão escolhida antes de uso comercial.
- Inferência: igual ao fornecedor de modelo selecionado; não é gratuita por usar Hermes.
- Hosting: começar por $0 se ainda não existir worker; quando necessário, um contentor pequeno/VPS controlado pode começar em cerca de €5–15/mês, mas só depois de testes de segurança e monitorização.
- Decisão: não adicionar este custo fixo antes de existirem tarefas agendadas que justifiquem uma máquina sempre disponível.

## Integrações

### Rotas — antes do piloto, mas em modo simples

1. Geocodificar e guardar coordenadas quando a morada é criada/corrigida.
2. Profissional escolhe o ponto de partida; por defeito, localização atual apenas com permissão.
3. Calcular duração e distância apenas quando os trabalhos do dia mudam ou o utilizador toca em “Atualizar rota”.
4. Mostrar sugestão de ordem, duração total e espaço para estacionamento/tempo de margem.
5. Abrir Apple Maps no iOS e Google Maps/Waze no Android para navegação.
6. Guardar resultados em cache por data + paragens + origem durante pelo menos 15 minutos.

Não ativar otimização automática da ordem até confirmarmos a lógica de prioridades, janelas de horário e a aceitação do utilizador. A atual função calcula uma rota simples; falta autenticação, geocodificação, cache, quotas, origem dinâmica e o fluxo de ordem de visitas.

A Google Routes API é pay-as-you-go, requer billing e cobra pedidos `Compute Routes` por consulta e matrizes por elemento. Configurar quotas diárias e alertas desde o primeiro dia; não assumir preços fixos no plano porque os SKUs variam por funcionalidade. [Google Routes: uso e faturação](https://developers.google.com/maps/documentation/routes/usage-and-billing).

### Calendário — antes do piloto, unidirecional

- A agenda interna é a fonte de verdade.
- Criar evento no calendário nativo apenas por ação do profissional.
- Guardar `external_event_id` se a biblioteca/plataforma o devolver; caso contrário marcar como “adicionado externamente”.
- Não ler ou alterar o calendário completo no piloto.
- Sincronização bidirecional só depois de haver uma política clara de conflitos, permissões e suporte.

### WhatsApp — preparar, não depender dele no piloto inicial

- Fase 0: botão “Enviar WhatsApp” abre a conversa com texto preenchido; sem API e sem custo Meta.
- Fase 1: Meta Embedded Signup para cada profissional ligar a sua WABA e número.
- Fase 2: webhook validado, inbox de mensagens e rascunhos preparados pela IA.
- Fase 3: templates para confirmações, lembretes e seguimento, sempre com aprovação inicial.

Cada profissional tem a sua conta/número; tokens cifrados apenas no servidor. A faturação Meta depende de tipo de mensagem, país e regras que evoluem; recolher a tabela oficial no onboarding e mostrar estimativa antes de ativar automações. Não colocar custos Meta na subscrição inicial nem automatizar mensagens antes da aprovação da Meta. [Meta WhatsApp Business Platform](https://www.postman.com/meta/whatsapp-business-platform/overview) e [preços da plataforma](https://business.whatsapp.com/products/platform-pricing).

## Custos operacionais e regra de sobrevivência financeira

### Orçamento mensal recomendado para o piloto

| Item | Antes do primeiro utilizador | Piloto de 5 | Regra |
| --- | ---: | ---: | --- |
| Flutter/web estático | €0 | €0 | Vercel/GitHub existente |
| Supabase | €0 | €0–25 | Free enquanto ativo e suficiente; Pro ao precisar de continuidade/backups |
| OpenAI/API | €0 | €10–30 de teto | Limite técnico e alerta a 50/80/100% |
| Google Routes | €0 | €0–10 de teto | Cache + quota diária |
| Hermes worker | €0 | €0 | Só depois de automações reais |
| WhatsApp Cloud API | €0 | €0 | Adiar para fase 1; mensagens pagas à parte |
| Domínio/Apple/Google stores | preparar | custos de conta anuais | Só quando distribuir fora do teste fechado |
| Total de caixa mensal | **€0–10** | **€10–65** | Não avançar sem limite de gasto |

Supabase Free inclui projeto limitado e pode pausar após inatividade; Pro começa em $25/mês e inclui um micro compute/mais recursos. Para um piloto ativo, começar Free é sensato, mas tratar o salto para Pro como custo de continuidade assim que existir dependência de produção. [Supabase Pricing](https://supabase.com/pricing).

### Política de preços do produto para o piloto

- Não cobrar aos primeiros 5 durante 30 dias; em troca, recolher feedback estruturado e autorização para entrevistas curtas.
- Depois, pedir uma decisão clara: continuar gratuitamente mais 30 dias com feedback ativo, ou testar preço fundador.
- Hipótese de preço fundador a validar: €19–29/mês para agenda/operação; IA com utilização justa incluída e extras só quando houver custo mensurável.
- Nunca vender “IA ilimitada”. Vender “assistente que organiza o trabalho”; colocar limites transparentes de automações/mensagens.
- Objetivo antes de escalar: pelo menos 3 dos 5 dispostos a pagar, mesmo que seja um valor fundador baixo.

## Instrumentação e métricas

### Métricas de produto

- Ativação: criou 3 clientes, 3 trabalhos e uma agenda no primeiro dia.
- Adoção: dias ativos por semana, trabalhos criados/concluídos, lembretes usados.
- Retenção: profissionais ativos após 7, 14 e 28 dias.
- Valor: minutos poupados reportados, faltas evitadas, orçamentos acompanhados, rota reorganizada.
- Confiança: sugestões IA aceites/corrigidas/rejeitadas, ações desfeitas, erros de dados.
- Monetização: intenção de pagar, preço aceite e motivos de recusa.

### Métricas técnicas

- Crash-free users, erros por endpoint, falhas de sincronização, latência p50/p95.
- Custo por organização e por funcionalidade: IA, rotas, mensagens, storage.
- Taxa de rate limit, webhook duplicado, falha de notificações e conflitos de edição.
- Dashboard semanal enviado apenas à equipa, sem dados identificáveis de clientes.

## Plano de execução

### Semana 1 — tornar a app real

- Criar projetos Supabase dev/prod, aplicar migrações e configurar segredos.
- Adicionar `supabase_flutter`, autenticação e repositórios remotos.
- Ligar clientes e trabalhos reais, mantendo cache/offline.
- Criar seeds de teste e testes RLS com duas contas.
- Definir nome temporário, bundle IDs e ambiente de distribuição.

**Saída:** uma pessoa consegue entrar em dois dispositivos e ver os mesmos trabalhos sem expor dados a outro utilizador.

### Semana 2 — operação diária confiável

- Agenda diária/semana, edição de horário, conflitos e disponibilidade.
- Conclusão de trabalho, materiais e notas/fotos básicas.
- Notificações locais robustas e criação de evento no calendário.
- Exportação simples de dados, crash reporting e analytics mínimo.

**Saída:** o profissional consegue trabalhar uma semana sem papel para agenda, clientes e trabalhos.

### Semana 3 — rota e base de IA

- Fechar geocodificação, cache e segurança da Edge Function de rota.
- Ligar vista Rota a dados reais e abrir app de navegação.
- Criar tabelas `agent_runs`, `agent_actions`, `agent_memories`, `usage_events`.
- Construir Agent Gateway com um único fluxo: texto → rascunho de trabalho.
- Adicionar avaliação manual de 30 pedidos reais/anónimos.

**Saída:** a IA cria rascunhos verificáveis, mas não altera nada sem aprovação.

### Semana 4 — piloto fechado

- TestFlight/Google Internal Testing, onboarding guiado e canal de suporte.
- Convidar Nuno primeiro; só depois os quatro contactos indicados.
- Entrevista inicial de 20 minutos, recolha de rotina atual e definição de sucesso individual.
- Ativar feature flags para IA, rota e calendário por utilizador.
- Rever diariamente erros e custos; entrevista semanal de 10 minutos.

**Saída:** cinco pessoas a usar dados reais sem dependência de WhatsApp API ou Hermes.

### Mês 2 — consolidar o que for usado

- Corrigir fricções encontradas no piloto antes de adicionar módulos.
- IA para organizar o dia, rascunhar mensagens e gerar orçamento simples.
- Histórico por cliente, fotos, PDF de orçamento e pesquisa.
- Melhorar rota com janelas de horário e prioridades.
- Introduzir WhatsApp “abrir conversa com texto” e medir utilização.

### Meses 3–4 — comunicação e automações controladas

- Iniciar candidatura/configuração Meta e Embedded Signup.
- Implementar inbox/webhook, mensagens recebidas e rascunhos IA.
- Testar Hermes como worker apenas no ambiente interno: resumo diário, seguimento de orçamento e fila de tarefas.
- Avaliar se os fluxos Hermes superam a API direta em sucesso, custo e manutenção.
- Adicionar equipa pequena/assistente administrativo apenas se um piloto o pedir.

### Meses 5–6 — primeira versão vendável

- Plano pago, limites de uso, faturação e gestão de subscrição.
- WhatsApp API para quem ligar a conta, com aprovações, templates e custo visível.
- Automação de lembretes/seguimento opt-in.
- Calendário com sincronização mais profunda apenas para utilizadores que a peçam.
- Biblioteca de modelos de orçamento e personalização por profissão.

### Meses 7–9 — escalar com prova, não com suposições

- Onboarding self-service e importação CSV de clientes/trabalhos.
- Painel de custo/margem por profissional e melhorias de recomendação agregada com consentimento.
- Equipa, permissões, múltiplas carrinhas e relatórios apenas se houver procura.
- Endurecimento de segurança, observabilidade e suporte.
- Avaliar separadamente canalizadores, eletricistas e outras profissões; não diluir proposta cedo.

## Critérios para avançar ou parar cada aposta

| Aposta | Avançar quando | Não avançar se |
| --- | --- | --- |
| IA de criação de pedidos | >70% dos rascunhos são aceites com pouca edição | profissionais preferem sempre formulário manual |
| IA de planeamento | reduz conflitos/tempo e é aceite >50% das vezes | rota sugerida é ignorada ou obriga a demasiadas correções |
| WhatsApp API | 3+ pilotos pedem receber/tratar mensagens na app | só querem abrir conversa manualmente |
| Hermes | automatizações ganham qualidade/tempo comprovado vs API direta | cria mais manutenção, falhas ou custo que valor |
| Sincronização calendário | há pedidos repetidos e regra de conflitos definida | cria suporte e duplicações sem utilização real |
| Pagamento | 3/5 pilotos dizem sim a preço fundador | não existe uso semanal ou problema forte |

## Riscos a vigiar desde já

- **Dados misturados:** resolver com organização + RLS + testes automatizados, não apenas confiança no prompt.
- **IA inventa informação:** usar dados estruturados, JSON estrito, ferramentas pequenas e confirmações.
- **Custos invisíveis:** orçamento por fornecedor, quotas, alertas e registo por ação.
- **Dependência Meta:** WhatsApp é uma integração de fase 1, não requisito do primeiro piloto.
- **Demasiado desenvolvimento antes de aprender:** feature flags e entrevistas semanais; retirar funcionalidades que ninguém usa.
- **Perder confiança do profissional:** explicar sempre a sugestão, permitir desfazer e nunca enviar/mover algo sem autorização no início.
- **Privacidade:** minimizar dados enviados ao modelo, `store: false` para pedidos de IA e política clara de retenção.

## Próxima sequência concreta

1. Criar o projeto Supabase e aplicar uma migração melhorada com `organizations`.
2. Ligar autenticação e persistência real de clientes/trabalhos no Flutter.
3. Fechar agenda, conflitos, notificações e calendário unidirecional.
4. Ligar rota segura com cache e quotas.
5. Implementar primeiro fluxo IA: criar rascunho de trabalho a partir de texto/voz.
6. Distribuir a Nuno em teste fechado e medir durante uma semana antes de convidar os restantes quatro.

