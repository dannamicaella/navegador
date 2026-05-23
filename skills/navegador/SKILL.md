---
name: Navegador
description: Controla o Google Chrome do usuário pelo terminal via o comando `navegador`. Use sempre que o usuário pedir para abrir sites, navegar, clicar, preencher formulários, ler conteúdo de páginas, mandar mensagens em redes sociais, controlar Netflix/YouTube, fazer login em serviços, ou qualquer automação de navegador. Use OBRIGATORIAMENTE esta skill sempre que o usuário mencionar "Navegador" na mensagem.
---

# Skill Navegador

Você controla o **Google Chrome do usuário humano** através de um único comando de terminal chamado `navegador`. O Chrome roda com um perfil persistente em `%USERPROFILE%\Navegador`, então logins, cookies e sessões ficam salvos entre execuções — o usuário só precisa entrar em cada site uma vez.

## Regra de ouro

**Sempre que precisar controlar o navegador, use o comando `navegador` no terminal.** Não use Playwright, Puppeteer, Selenium, MCP browser, nem qualquer outra ferramenta. Se você tem acesso a um terminal PowerShell (ou bash dentro de WSL2 Ubuntu 24+), o comando `navegador` está disponível e é o único caminho correto.

Se o usuário mencionar a palavra **"Navegador"** (ou disser `/Navegador ...`), interprete como uma ordem explícita para usar esta skill — não pergunte, não sugira alternativas, vá direto para o comando `navegador`.

## Como o comando funciona

`navegador` é uma função que repassa todos os argumentos para o binário `agent-browser` fixando o perfil do Chrome em `%USERPROFILE%\Navegador` e rodando em modo `--headed` (com janela visível para o usuário). Portanto, qualquer subcomando válido do `agent-browser` é válido para `navegador`:

```
navegador open https://netflix.com
navegador snapshot
navegador click @ref-id-vindo-do-snapshot
navegador type @ref-do-input "texto"
navegador press Enter
navegador wait 2000
navegador get text @ref
navegador close
```

Você pode também rodar `navegador --help` para listar todos os subcomandos disponíveis na máquina do usuário.

## Workflow padrão para qualquer tarefa

Siga esta sequência em quase todo pedido. Não tente adivinhar seletores CSS — use refs do `snapshot`, é mais robusto.

1. **Abrir o site:** `navegador open <url>`
2. **Esperar carregar:** `navegador wait <ms>` ou `navegador wait <seletor>`
3. **Tirar snapshot:** `navegador snapshot` — retorna a árvore de acessibilidade com `@refs` que você usa nas próximas ações.
4. **Agir nos elementos:** `navegador click @ref`, `navegador type @ref "texto"`, `navegador fill @ref "texto"`, `navegador press Enter`, etc.
5. **Conferir resultado:** tire outro `navegador snapshot` ou `navegador get text @ref` para confirmar.
6. **NÃO feche o navegador** ao final de uma tarefa, a menos que o usuário peça explicitamente. O perfil é persistente e o usuário pode querer continuar usando manualmente.

### Quando o site já estiver aberto

Antes de abrir um site novamente, considere `navegador snapshot` — se a sessão já estiver na URL certa, pule o `open`. Use `navegador tab list` para ver as abas e `navegador tab <n>` para trocar.

### Login em sites

O perfil é persistente, então normalmente o usuário **já está logado**. Se o snapshot mostrar tela de login, **peça ao humano para fazer login na janela do Chrome que abriu** e dizer "continuar" — não tente automatizar login com senha. Após o usuário logar uma vez, futuras execuções já estarão autenticadas.

### Lendo conteúdo de uma página

Para "leia meu perfil do X" ou "veja o que está em Y":

1. `navegador open <url>`
2. `navegador wait 2000` (ou espere por um elemento específico)
3. `navegador snapshot` — leia o conteúdo da árvore de acessibilidade
4. Para texto bruto de uma seção específica: `navegador get text @ref`

### Mandando mensagens em redes sociais (Facebook, Instagram, WhatsApp Web, LinkedIn)

1. Abra o site e tire um snapshot.
2. Procure o campo de busca de contatos pelo nome do destinatário.
3. Clique no contato correto (pelo `@ref` do snapshot).
4. Clique no campo de mensagem, use `navegador type @ref "mensagem"` ou `navegador fill @ref "mensagem"`.
5. **Antes de apertar Enter / enviar, mostre ao usuário exatamente o que vai mandar e para quem, e peça confirmação.** Mensagens enviadas são irreversíveis.
6. Após confirmação, `navegador press Enter` ou clique no botão de enviar.

### Controlando Netflix, YouTube, players de vídeo

Players costumam responder bem a atalhos de teclado. Use `navegador press` com a tecla certa em vez de procurar botões na tela:

- Netflix: próximo episódio costuma ser botão visível ao final; use `snapshot` + `click @ref`. Play/pause: `navegador press Space`.
- YouTube: `Space` play/pause, `Shift+N` próximo, `f` fullscreen, `m` mute.

Se o player estiver em foco errado, primeiro `navegador click @ref-do-player` e depois mande a tecla.

## Idempotência e estado

- O perfil é **único e compartilhado** entre todas as chamadas. Não crie outros perfis. Não passe `--profile` manualmente — o comando `navegador` já faz isso.
- Não rode `agent-browser` direto: sempre `navegador`. Isso garante que o perfil correto seja usado.
- Se algo parecer travado, `navegador close` e recomece do `open`. Como o perfil é persistente, logins continuam válidos.

## Quando algo não funcionar

Se uma tarefa **não for possível** com os subcomandos atuais de `navegador`, ou se você encontrar um bug, ou se identificar uma melhoria que beneficiaria todos os usuários da skill, **sugira ao usuário abrir uma issue no GitHub**:

> Esta tarefa esbarrou em uma limitação do navegador. Se quiser, abra uma issue em https://github.com/giovannefeitosa/navegador/issues descrevendo o que estava tentando fazer — isso ajuda a melhorar a skill para todo mundo.

Não abra a issue automaticamente. Apenas sugira, com o link, e siga em frente com o que for possível.

## O que NÃO fazer

- Não use Playwright, Puppeteer, Selenium ou MCP de navegador. Use sempre `navegador`.
- Não passe `--profile` ou `--headed` manualmente — já estão fixados pela função `navegador`.
- Não feche o navegador no final, a menos que o usuário peça.
- Não tente automatizar logins com senha. Peça ao humano para logar.
- Não envie mensagens, faça compras, ou execute ações irreversíveis sem confirmação explícita do humano.
- Não invente seletores CSS — use `snapshot` e refs.
