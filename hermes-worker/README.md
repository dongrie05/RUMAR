# Hermes worker no Mac mini

Este worker é a primeira ponte entre a app e o teu perfil Hermes. O Mac mini
faz polling de tarefas no Supabase, reclama uma tarefa de forma atómica, executa
o Hermes e grava o resultado. Não existe porta HTTP aberta no Mac mini.

## Configuração

1. Aplicar `docs/SUPABASE_SCHEMA.sql` no projeto Supabase.
2. Instalar o Hermes e criar o perfil isolado `rumar`. O comando esperado por
   defeito é `~/.local/bin/rumar`.
3. Criar um ficheiro `.env` local (não commitar):

```text
SUPABASE_URL=https://PROJECT.supabase.co
SUPABASE_SECRET_KEY=sb_secret_...
HERMES_PROFILE_HOME=/Users/UTILIZADOR/.hermes/profiles/rumar
HERMES_COMMAND=/Users/UTILIZADOR/.local/bin/rumar
HERMES_TIMEOUT_SECONDS=90
WORKER_NAME=mac-mini-field-ops
POLL_SECONDS=3
```

4. Instalar dependências do worker: `python3 -m pip install requests`.
5. Iniciar: `python3 hermes-worker/worker.py`.

O `SUPABASE_SECRET_KEY` dá acesso de sistema e nunca pode entrar no
Flutter, numa Edge Function pública, no Git ou num screenshot. Guardá-lo apenas
no Mac mini e rodar o utilizador do worker sem permissões administrativas.

O worker também aceita `SUPABASE_SERVICE_ROLE_KEY` para projetos antigos com
uma chave JWT legada, mas prefere a nova `SUPABASE_SECRET_KEY`.

## Teste manual

Depois de publicar `agent-gateway`, criar uma tarefa autenticada a partir da
app ou do Supabase client. O worker deve mudar `queued → running → succeeded`
e preencher `result.text`.

Esta versão é deliberadamente read-only. Antes de permitir qualquer ação,
devem ser adicionados handlers tipados, aprovação na app, idempotência e um
registo em `agent_actions`.

O perfil usa `RUMAR_SOUL.md` como fonte versionada das regras. Depois de alterar
esse ficheiro, deve ser novamente copiado para
`~/.hermes/profiles/rumar/SOUL.md`.

O worker chama o alias do perfil diretamente, sem `shell`, e força também o
`HERMES_HOME` isolado. As ferramentas e a memória nativa do Hermes devem ficar
desativadas neste perfil; a memória durável por profissional pertence ao
Supabase da RUMAR.

## Operação no Mac mini

- Desativar suspensão enquanto o piloto estiver ativo.
- Criar um `launchd` LaunchAgent para reiniciar o processo após reboot.
- Verificar semanalmente espaço dos logs e atualizar o Hermes manualmente.
- Se o Mac estiver desligado, as tarefas ficam na fila e são processadas depois;
  a app deve mostrar “IA temporariamente indisponível”, nunca perder o pedido.
