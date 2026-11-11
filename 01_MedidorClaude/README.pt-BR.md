# MedidorClaude

App nativo de barra de menu do macOS e status line de terminal que mostram quanto do uso do Claude Code ainda resta, a saúde de cada sessão aberta e se o prompt caching ainda está válido.

```
5h ██████░░░░ 62% ↻2h5m │ Sem ███░░░░░░░ 31% ↻2d7h │ Ctx 18% 180k/1.0M │ 🔥 ativo 42 min │ ● atenção
```

## O que mostra

- **Limites**: janela de 5 horas e limite semanal, com porcentagem e tempo até reiniciar.
- **Uma linha por sessão aberta**: contexto usado (`tokens de tamanho da janela`) e saúde de cada uma.
- **Saúde**: saudável (abaixo de 50%), atenção (50–79%), pesada (80–95%) e nova sessão (96% ou mais), pelo pior valor entre janela de 5h, semana e contexto.
- **Prompt caching**: 🔥 ativo (60–31 min), 💨 esfriando (30–10 min), 💀 acabando (10 min ou menos), 💀 expirado.
- **Custo zero de tokens**: nada aqui chama modelo nem rede.

## Instalação

Requer macOS 14+, Swift (Xcode ou Command Line Tools), `jq` e Claude Code.

```bash
git clone https://github.com/matheuscssouza/tools.git
cd tools/01_MedidorClaude
scripts/install.sh              # --login-item para abrir no login
```

O instalador compila o app em `~/Applications`, copia a status line para `~/.claude/statusline.sh` e acrescenta `statusLine` e um hook `SessionEnd` ao `~/.claude/settings.json`, com backup em `settings.json.bak.<timestamp>`. Para fechar o app, use `⌘Q` com o painel aberto. Para remover tudo: `scripts/uninstall.sh`.

## Limitações

- A contagem do prompt caching é uma estimativa: assume TTL de 1 hora contado da última atividade. Com TTL de 5 minutos, ela fica otimista.
- Os limites (`rate_limits`) só aparecem em alguns planos e versões do Claude Code.
- O formato do payload da status line não é um contrato público estável.

Detalhes de arquitetura, configuração e desenvolvimento estão no [README em inglês](./README.md).

## Privacidade

Tudo fica na sua máquina, sem rede e sem telemetria.

## Licença

[MIT](../LICENSE)
