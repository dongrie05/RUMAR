# Integrações — decisão técnica

## WhatsApp: uma conta por profissional

Sim. O produto deve ser multi-tenant: cada profissional cria ou liga o seu próprio WhatsApp Business Account (WABA) e número. Na base de dados guardamos apenas a relação `owner_id -> waba_id -> phone_number_id`; o token fica cifrado no servidor.

O fluxo recomendado é Meta Embedded Signup:

1. O profissional escolhe “Ligar WhatsApp” na app/web.
2. Abrimos o onboarding oficial da Meta.
3. Ele autentica a empresa, escolhe/cria o WABA e verifica o número.
4. O backend recebe os identificadores e guarda a ligação para esse utilizador.
5. O webhook recebe mensagens desse número e associa-as ao profissional certo.

Não devemos usar QR codes, tokens dentro da app ou um número partilhado. Cada profissional mantém o seu número e a sua faturação. A Meta exige revisão/permissões avançadas para um produto que faça onboarding de outras empresas; preparar esta submissão cedo evita bloquear o lançamento.

## Rotas: Google Routes API + app de navegação nativa

Recomendação para Apple e Android: usar Google Routes API apenas no backend para geocodificar moradas e calcular a ordem/duração; abrir depois Apple Maps no iOS e Google Maps/Waze no Android para a navegação turn-by-turn.

Vantagens:

- um cálculo consistente entre plataformas;
- não obrigamos a construir navegação própria;
- podemos trocar o fornecedor mais tarde;
- controlamos custo com cache, quotas diárias e pedidos apenas quando a rota muda.

As moradas devem ser convertidas para coordenadas antes do cálculo e devemos pedir apenas os campos necessários. A chave nunca fica embutida no Flutter; passa por uma Edge Function.

## Calendário: sincronização opcional, não fonte principal

A agenda da app continua a ser a fonte de verdade. O botão “Adicionar ao calendário” cria um evento no calendário nativo:

- iOS: EventKit / Calendário Apple;
- Android: CalendarContract / calendário escolhido pelo utilizador.

Não recomendamos ler todos os calendários por defeito. Pedimos apenas permissão para criar eventos, com uma opção explícita. Assim reduzimos fricção e privacidade. Quando a sincronização bidirecional for necessária, adicionamos permissões de leitura e um `external_event_id` por trabalho.
