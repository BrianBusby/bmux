> Esta tradução foi gerada pelo Claude. Se você tiver sugestões de melhoria, abra um PR.

<h1 align="center">bmux</h1>
<p align="center">Um terminal macOS baseado em Ghostty com abas verticais e notificações para agentes de programação com IA</p>

<p align="center">
  <a href="https://github.com/manaflow-ai/bmux/releases/latest/download/bmux-macos.dmg">
    <img src="../assets/macos-badge.png" alt="Baixar bmux para macOS" width="180" />
  </a>
</p>

<p align="center">
  <a href="../../README.md">English</a> | <a href="README.ja.md">日本語</a> | <a href="README.vi.md">Tiếng Việt</a> | <a href="README.zh-CN.md">简体中文</a> | <a href="README.zh-TW.md">繁體中文</a> | <a href="README.ko.md">한국어</a> | <a href="README.de.md">Deutsch</a> | <a href="README.es.md">Español</a> | <a href="README.fr.md">Français</a> | <a href="README.it.md">Italiano</a> | <a href="README.da.md">Dansk</a> | <a href="README.pl.md">Polski</a> | <a href="README.ru.md">Русский</a> | <a href="README.bs.md">Bosanski</a> | <a href="README.ar.md">العربية</a> | <a href="README.no.md">Norsk</a> | Português (Brasil) | <a href="README.th.md">ไทย</a> | <a href="README.tr.md">Türkçe</a> | <a href="README.km.md">ភាសាខ្មែរ</a> | <a href="README.uk.md">Українська</a>
</p>

<p align="center">
  <a href="https://x.com/manaflowai"><img src="https://img.shields.io/badge/@manaflow-555?logo=x" alt="X / Twitter" /></a>
  <a href="https://discord.gg/xsgFEVrWCZ"><img src="https://img.shields.io/badge/Discord-555?logo=discord" alt="Discord" /></a>
  <a href="https://github.com/manaflow-ai/bmux"><img src="https://img.shields.io/github/stars/manaflow-ai/bmux?style=flat&logo=github&label=stars&color=4c71f2" alt="GitHub stars" /></a>
</p>

<p align="center">
  <img src="../assets/main-first-image.png" alt="Captura de tela do bmux" width="900" />
</p>

<p align="center">
  <a href="https://www.youtube.com/watch?v=i-WxO5YUTOs">▶ Vídeo de demonstração</a> · <a href="https://bmux.com/blog/zen-of-bmux">O Zen do bmux</a>
</p>

## Recursos

<table>
<tr>
<td width="40%" valign="middle">
<h3>Anéis de notificação</h3>
Os painéis recebem um anel azul e as abas acendem quando agentes de programação precisam da sua atenção
</td>
<td width="60%">
<img src="../assets/notification-rings.png" alt="Anéis de notificação" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>Painel de notificações</h3>
Veja todas as notificações pendentes em um só lugar, vá direto para a mais recente não lida
</td>
<td width="60%">
<img src="../assets/sidebar-notification-badge.png" alt="Badge de notificação na barra lateral" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>Navegador integrado</h3>
Divida um navegador ao lado do seu terminal com uma API programável portada do <a href="https://github.com/vercel-labs/agent-browser">agent-browser</a>
</td>
<td width="60%">
<img src="../assets/built-in-browser.png" alt="Navegador integrado" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>Abas verticais + horizontais</h3>
A barra lateral mostra o branch do git, status/número do PR vinculado, diretório de trabalho, portas em escuta e texto da última notificação. Divida horizontal e verticalmente.
</td>
<td width="60%">
<img src="../assets/vertical-horizontal-tabs-and-splits.png" alt="Abas verticais e painéis divididos" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>SSH</h3>
<code>bmux ssh user@remote</code> cria um workspace para uma máquina remota. Painéis do navegador são roteados pela rede remota, então localhost simplesmente funciona. Arraste uma imagem para uma sessão remota para fazer upload via scp.
</td>
<td width="60%">
<img src="../assets/ssh.png" alt="bmux SSH" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>Claude Code Teams</h3>
<code>bmux claude-teams</code> executa o modo de companheiros de equipe do Claude Code com um único comando. Os companheiros aparecem como divisões nativas com metadados na barra lateral e notificações. Sem necessidade de tmux.
</td>
<td width="60%">
<img src="../assets/claude-code-teams.png" alt="Claude Code Teams" width="100%" />
</td>
</tr>
</table>

- **Import de navegador** — Importe cookies, histórico e sessões do Chrome, Firefox, Arc e mais de 20 navegadores para que painéis do navegador iniciem autenticados
- **Comandos personalizados** — Defina ações específicas do projeto em [`bmux.json`](https://bmux.com/docs/custom-commands) que são lançadas pela paleta de comandos
- **Programável** — CLI e socket API para criar workspaces, dividir painéis, enviar teclas e automatizar o navegador
- **App nativo macOS** — Construído com Swift e AppKit, não Electron. Inicialização rápida, baixo consumo de memória.
- **Compatível com Ghostty** — Lê sua configuração existente em `~/.config/ghostty/config` para temas, fontes e cores
- **Acelerado por GPU** — Alimentado por libghostty para renderização suave
- **Atalhos de teclado** — [Atalhos abrangentes](https://bmux.com/docs/keyboard-shortcuts) para workspaces, divisões, navegador e mais
- **Open source** — Gratuito e licenciado sob GPL

## Instalação

### DMG (recomendado)

<a href="https://github.com/manaflow-ai/bmux/releases/latest/download/bmux-macos.dmg">
  <img src="../assets/macos-badge.png" alt="Baixar bmux para macOS" width="180" />
</a>

Abra o `.dmg` e arraste o bmux para a pasta Aplicativos. O bmux se atualiza automaticamente via Sparkle, então você só precisa baixar uma vez.

### Homebrew

```bash
brew tap manaflow-ai/bmux
brew install --cask bmux
```

Para atualizar depois:

```bash
brew upgrade --cask bmux
```

Na primeira execução, o macOS pode pedir para você confirmar a abertura de um app de um desenvolvedor identificado. Clique em **Abrir** para continuar.

## Por que o bmux?

Eu executo muitas sessões de Claude Code e Codex em paralelo. Eu estava usando o Ghostty com vários painéis divididos e contando com as notificações nativas do macOS para saber quando um agente precisava de mim. Mas o corpo da notificação do Claude Code é sempre apenas "Claude is waiting for your input" sem contexto, e com abas suficientes abertas eu não conseguia nem ler os títulos mais.

Eu tentei alguns orquestradores de código, mas a maioria era apps Electron/Tauri e o desempenho me incomodava. Eu também prefiro o terminal, já que orquestradores GUI te prendem no fluxo de trabalho deles. Então eu construí o bmux como um app nativo macOS em Swift/AppKit. Ele usa o libghostty para renderização do terminal e lê sua configuração existente do Ghostty para temas, fontes e cores.

As principais adições são a barra lateral e o sistema de notificações. A barra lateral tem abas verticais que mostram o branch do git, status/número do PR vinculado, diretório de trabalho, portas em escuta e o texto da última notificação para cada workspace. O sistema de notificações captura sequências do terminal (OSC 9/99/777) e tem uma CLI (`bmux notify`) que você pode conectar aos hooks de agentes para Claude Code, OpenCode, etc. Quando um agente está esperando, seu painel recebe um anel azul e a aba acende na barra lateral, para que eu possa ver qual precisa de mim entre divisões e abas. Cmd+Shift+U pula para o mais recente não lido.

O navegador integrado tem uma API programável portada do [agent-browser](https://github.com/vercel-labs/agent-browser). Agentes podem capturar a árvore de acessibilidade, obter referências de elementos, clicar, preencher formulários e executar JS. Você pode dividir um painel de navegador ao lado do seu terminal e fazer o Claude Code interagir diretamente com seu servidor de desenvolvimento.

Tudo é programável através da CLI e socket API — criar workspaces/abas, dividir painéis, enviar teclas, abrir URLs no navegador.

## O Zen do bmux

O bmux não é prescritivo sobre como os desenvolvedores usam suas ferramentas. É um terminal e navegador com uma CLI, e o resto é com você.

O bmux é uma primitiva, não uma solução. Ele te dá um terminal, um navegador, notificações, workspaces, divisões, abas e uma CLI para controlar tudo isso. O bmux não te força a usar agentes de programação de uma forma específica. O que você constrói com as primitivas é seu.

Os melhores desenvolvedores sempre construíram suas próprias ferramentas. Ninguém descobriu ainda a melhor forma de trabalhar com agentes, e as equipes construindo produtos fechados definitivamente também não. Os desenvolvedores mais próximos de suas próprias bases de código vão descobrir primeiro.

Dê a um milhão de desenvolvedores primitivas combináveis e eles coletivamente encontrarão os fluxos de trabalho mais eficientes mais rápido do que qualquer equipe de produto poderia projetar de cima para baixo.

## Documentação

Para mais informações sobre como configurar o bmux, [acesse nossa documentação](https://bmux.com/docs/getting-started?utm_source=readme).

## Atalhos de Teclado

### Áreas de Trabalho

| Atalho | Ação |
|----------|--------|
| ⌘ N | Novo workspace |
| ⌘ 1–8 | Ir para workspace 1–8 |
| ⌘ 9 | Ir para último workspace |
| ⌃ ⌘ ] | Próximo workspace |
| ⌃ ⌘ [ | Workspace anterior |
| ⌘ ⇧ W | Fechar workspace |
| ⌘ ⇧ R | Renomear workspace |
| ⌥ ⌘ E | Editar descrição do workspace |
| ⌘ B | Alternar barra lateral |
| ⌥ ⌘ B | Alternar barra lateral direita |
| ⌘ ⇧ E | Alternar foco da barra lateral direita |

### Superfícies

| Atalho | Ação |
|----------|--------|
| ⌘ T | Nova surface |
| ⌘ ⇧ ] | Próxima surface |
| ⌘ ⇧ [ | Surface anterior |
| ⌃ Tab | Próxima surface |
| ⌃ ⇧ Tab | Surface anterior |
| ⌃ 1–8 | Ir para surface 1–8 |
| ⌃ 9 | Ir para última surface |
| ⌘ W | Fechar surface |

### Painéis Divididos

| Atalho | Ação |
|----------|--------|
| ⌘ D | Dividir à direita |
| ⌘ ⇧ D | Dividir para baixo |
| ⌥ ⌘ ← → ↑ ↓ | Focar painel direcionalmente |
| ⌘ ⇧ H | Piscar painel focado |

### Navegador

Os atalhos de ferramentas do desenvolvedor do navegador seguem os padrões do Safari e podem ser personalizados em `Configurações → Atalhos de Teclado`.
Os atalhos de navegação da paleta de comandos, incluindo ⌃ P, também são personalizáveis e podem ser limpos para que a tecla pressionada chegue ao terminal ativo.

| Atalho | Ação |
|----------|--------|
| ⌘ ⇧ L | Abrir navegador em divisão |
| ⌘ L | Focar barra de endereço |
| ⌘ [ | Voltar |
| ⌘ ] | Avançar |
| ⌘ R | Recarregar página |
| ⌥ ⌘ I | Alternar Ferramentas do Desenvolvedor (padrão Safari) |
| ⌥ ⌘ C | Mostrar Console JavaScript (padrão Safari) |

### Notificações

| Atalho | Ação |
|----------|--------|
| ⌘ I | Mostrar painel de notificações |
| ⌘ ⇧ U | Ir para última não lida |
| ⌥ ⌘ U | Alternar estado de não lida do item atual |
| ⌃ ⌘ U | Marcar item atual como não lido mais antigo e ir para a próxima não lida mais recente |

### Busca

| Atalho | Ação |
|----------|--------|
| ⌘ F | Buscar |
| ⌘ ⇧ F | Buscar no diretório |
| ⌘ G / ⌥ ⌘ G | Buscar próximo / anterior |
| ⌥ ⌘ ⇧ F | Ocultar barra de busca |
| ⌘ E | Usar seleção para busca |

### Terminal

| Atalho | Ação |
|----------|--------|
| ⌘ K | Limpar histórico de rolagem |
| ⌘ C | Copiar (com seleção) |
| ⌘ V | Colar |
| ⌘ + / ⌘ - | Aumentar / diminuir tamanho da fonte |
| ⌘ 0 | Redefinir tamanho da fonte |

### Janela

| Atalho | Ação |
|----------|--------|
| ⌘ ⇧ N | Nova janela |
| ⌘ ⇧ O | Reabrir sessão anterior |
| ⌘ , | Configurações |
| ⌘ ⇧ , | Recarregar configuração |
| ⌘ Q | Sair |

## Builds Noturnos

[Baixar bmux NIGHTLY](https://github.com/manaflow-ai/bmux/releases/download/nightly/bmux-nightly-macos.dmg)

O bmux NIGHTLY é um app separado com seu próprio bundle ID, então roda ao lado da versão estável. Construído automaticamente a partir do último commit em `main` e se atualiza automaticamente via seu próprio feed Sparkle.

Reporte bugs do nightly nas [GitHub Issues](https://github.com/manaflow-ai/bmux/issues) ou em [#nightly-bugs no Discord](https://discord.gg/xsgFEVrWCZ).

## Restauração de sessão

Ao sair, o bmux salva a sessão atual. Ao abrir novamente, o bmux restaura o estado
pertencente ao app:
- Layout de janelas/workspaces/painéis
- Diretórios de trabalho
- Histórico de rolagem do terminal (melhor esforço)
- URL do navegador e histórico de navegação

O bmux não cria checkpoints de estado arbitrário de processos ativos. tmux, vim, shells e
apps de terminal sem suporte reabrem como terminais normais.

Sessões de agentes compatíveis podem ser retomadas quando os hooks salvam um ID de sessão nativo.
Instale os hooks depois de instalar a CLI do agente para que seu binário esteja no `PATH`:

```bash
bmux hooks setup
bmux hooks setup codex
bmux hooks setup --agent opencode
```

`bmux hooks setup` instala os agentes compatíveis que encontra e imprime um resumo
dos agentes ignorados. As integrações de retomada compatíveis incluem Claude Code, Codex,
Grok, OpenCode, Pi, Amp, Cursor CLI, Gemini, Rovo Dev, Copilot, CodeBuddy,
Factory e Qoder. O Claude Code é tratado pelo wrapper Claude do bmux quando a integração
com o Claude está ativada nas Configurações.

Usuários avançados e integrações podem associar um comando personalizado de retomada à
surface de terminal atual. Isso é útil para ferramentas com estado durável próprio,
como sessões tmux ou CLIs de agentes customizados:

```bash
bmux surface resume set --kind tmux --checkpoint work --shell "tmux attach -t work"
bmux surface resume show --json
bmux surface resume clear --checkpoint work
```

A associação fica ligada à surface do bmux. Associações criadas pela CLI pública ou pelo
socket são salvas para inspeção e restauração manual, a menos que você aprove um prefixo de
comando assinado para restauração automática. Os prefixos aprovados também são associados ao
diretório de trabalho e aos valores exatos de ambiente, quando presentes. Revise ou edite as
aprovações em **Configurações > Terminal > Comandos de Retomada**. O bmux só executa
automaticamente associações de retomada que marca como confiáveis, como associações tmux
detectadas a partir de processos ativos ou prefixos aprovados pelo usuário. Chaves de ambiente
sensíveis, como tokens, senhas, segredos e chaves de API, são descartadas antes de salvar uma
associação de retomada.

Para manter os terminais de agentes restaurados inativos em vez de executar automaticamente seus comandos de retomada,
desative **Configurações > Terminal > Retomar Sessões de Agentes ao Reabrir** ou defina isto em
`~/.config/bmux/bmux.json`:

```json
{
  "terminal": {
    "autoResumeAgentSessions": false
  }
}
```

Isso desativa apenas os comandos automáticos de retomada de agentes. O bmux continua restaurando o layout salvo,
os diretórios de trabalho, o histórico de rolagem e o histórico do navegador.

Se você precisar reaplicar manualmente o último snapshot salvo, use:
- `Arquivo > Reabrir Sessão Anterior`
- `⌘ ⇧ O`
- `bmux restore-session`

Nos bastidores, o bmux grava um snapshot versionado em
`~/Library/Application Support/bmux/` e os hooks de agentes gravam mapeamentos de sessão
em `~/.bmuxterm/`. Na restauração, o bmux reconstrói o layout primeiro e depois executa o
comando de retomada nativo do agente compatível quando a retomada automática de agentes está ativada.

Leia o guia completo em <https://bmux.com/docs/session-restore>.

## FAQ

### Como o bmux se relaciona com o Ghostty?

O bmux não é um fork do Ghostty. Ele usa o [libghostty](https://github.com/ghostty-org/ghostty) como biblioteca para renderização do terminal, da mesma forma que apps usam o WebKit para visualizações web. O Ghostty é um terminal independente; o bmux é um app diferente construído sobre seu mecanismo de renderização.

### Quais plataformas ele suporta?

Apenas macOS, por enquanto. O bmux é um app nativo em Swift + AppKit.

### Existe um app para iOS?

Sim, em beta. Pareie seu iPhone com seu Mac na janela Mobile Connect e conecte-se aos seus terminais a partir do celular, com encaminhamento opcional das notificações do terminal. Ele é distribuído no TestFlight como bmux BETA. Veja a [documentação do iOS](https://bmux.com/docs/ios).

### Com quais agentes de programação o bmux funciona?

Todos eles. O bmux é um terminal, então qualquer agente que rode em um terminal funciona de imediato: Claude Code, Codex, OpenCode, Gemini CLI, Kiro, Aider, Goose, Amp, Cline, Cursor Agent e qualquer outra coisa que você possa iniciar pela linha de comando.

### O bmux pode orquestrar múltiplos agentes e subagentes?

Sim. Quando um agente cria subagentes ou companheiros de equipe, o bmux os transforma em painéis e divisões nativos em vez de processos ocultos em segundo plano. Ele suporta a orquestração multi-modelo de [Claude Code teams](https://bmux.com/docs/agent-integrations/claude-code-teams) e [oh-my-opencode](https://bmux.com/docs/agent-integrations/oh-my-opencode), para que cada agente de uma execução seja visível e controlável.

### Posso usar o bmux com máquinas remotas?

Sim. Abra workspaces via SSH e conecte-se a sessões tmux remotas, para que os agentes possam rodar em um host remoto enquanto você os controla a partir do bmux. Veja [SSH e remoto](https://bmux.com/docs/ssh).

### Como funcionam as notificações?

Quando um processo precisa de atenção, o bmux mostra anéis de notificação ao redor dos painéis, badges de não lidas na barra lateral, um popover de notificação e uma notificação de desktop do macOS. Elas disparam automaticamente via sequências de escape de terminal padrão (OSC 9/99/777), ou você pode acioná-las com a [CLI do bmux](https://bmux.com/docs/notifications#cli-usage) e [hooks de agentes](https://bmux.com/docs/notifications#integration-examples). Qualquer agente que suporte hooks ou OSC funciona, incluindo Claude Code, Codex, OpenCode e pi.

### O bmux é programável?

Sim. Toda ação está disponível através da CLI do bmux e de um socket Unix: criar workspaces, abrir painéis divididos, enviar entrada, ler o conteúdo da tela, tirar capturas de tela e controlar o navegador integrado. Veja a [referência da CLI](https://bmux.com/docs/api) e a documentação de [automação do navegador](https://bmux.com/docs/browser-automation).

### O que o navegador integrado pode fazer?

O bmux pode dividir um painel de navegador real ao lado do seu terminal, e ele é totalmente programável: navegar, capturar o DOM, clicar, digitar, executar JavaScript e ler atividade do console e da rede pela mesma socket API. Os agentes o usam para verificar suas próprias mudanças na web sem sair do bmux. Veja [automação do navegador](https://bmux.com/docs/browser-automation).

### O bmux tem skills?

Sim. Skills são fluxos de trabalho reutilizáveis que você pode dar a qualquer agente rodando no bmux, para coisas como controle da CLI, automação de workspaces, configurações e surfaces do navegador. Explore a coleção aberta em [bmux-skills](https://github.com/manaflow-ai/bmux-skills), ou leia a [documentação de skills](https://bmux.com/docs/skills).

### Posso personalizar os atalhos de teclado?

As teclas de atalho do terminal são lidas do seu arquivo de configuração do Ghostty (`~/.config/ghostty/config`). Os atalhos específicos do bmux (workspaces, divisões, navegador, notificações) podem ser personalizados nas Configurações. Veja os [atalhos padrão](https://bmux.com/docs/keyboard-shortcuts) para a lista completa.

### Posso personalizar o bmux?

Sim. A renderização do terminal usa sua configuração do Ghostty, então temas, fontes, cores e cursor são transferidos diretamente. As configurações próprias do bmux em `~/.config/bmux/bmux.json` controlam a barra lateral, a barra de abas, os painéis divididos e o comportamento, e todo [atalho de teclado](https://bmux.com/docs/keyboard-shortcuts) é editável. Veja [configuração](https://bmux.com/docs/configuration).

### Minhas sessões são salvas?

Sim. O bmux restaura suas janelas, workspaces, painéis, diretórios de trabalho e histórico de rolagem ao reabrir, e o estado sobrevive a uma reinicialização completa do computador, não apenas a sair do app. Sessões de agentes como Claude Code, Codex e OpenCode também voltam. Veja [restauração de sessão](https://bmux.com/docs/session-restore).

### Como ele se compara ao tmux?

O tmux é um multiplexador de terminal que roda dentro de qualquer terminal. O bmux é um app nativo macOS com uma GUI: abas verticais, painéis divididos, um navegador embutido e uma socket API, tudo integrado, sem necessidade de arquivos de configuração ou teclas de prefixo. Dito isso, muita gente roda o bmux com SSH e tmux juntos sem problemas, e o bmux pode se conectar às suas sessões tmux remotas nativamente ([beta](https://bmux.com/docs/remote-tmux)).

### O bmux é gratuito?

Sim, o bmux é gratuito para usar. O código-fonte está disponível no [GitHub](https://github.com/manaflow-ai/bmux).

### Como posso apoiar o bmux?

O bmux é gratuito e open source, e sempre será. Se você quiser apoiar o desenvolvimento e ter acesso antecipado ao que vem a seguir, incluindo o bmux AI, o app iOS e as Cloud VMs, confira a [bmux Founders Edition](https://github.com/manaflow-ai/bmux#founders-edition).

### Tenho uma solicitação de recurso ou encontrei um bug?

Queremos saber. Abra uma [issue](https://github.com/manaflow-ai/bmux/issues) ou [pull request](https://github.com/manaflow-ai/bmux/pulls) no GitHub, ou [envie um e-mail](mailto:founders@manaflow.com?subject=bmux%20feature%20request).

## Histórico de Estrelas

<a href="https://star-history.com/#manaflow-ai/bmux&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=manaflow-ai/bmux&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=manaflow-ai/bmux&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=manaflow-ai/bmux&type=Date" width="600" />
 </picture>
</a>

## Contribuindo

Formas de participar:

- Siga-nos no X para atualizações [@manaflowai](https://x.com/manaflowai), [@lawrencecchen](https://x.com/lawrencecchen), e [@austinywang](https://x.com/austinywang)
- Participe da conversa no [Discord](https://discord.gg/xsgFEVrWCZ)
- Crie e participe de [issues no GitHub](https://github.com/manaflow-ai/bmux/issues) e [discussões](https://github.com/manaflow-ai/bmux/discussions)
- Nos conte o que você está construindo com o bmux

## Comunidade

- [Discord](https://discord.gg/xsgFEVrWCZ)
- [GitHub](https://github.com/manaflow-ai/bmux)
- [X / Twitter](https://twitter.com/manaflowai)
- [YouTube](https://www.youtube.com/channel/UCAa89_j-TWkrXfk9A3CbASw)
- [LinkedIn](https://www.linkedin.com/company/manaflow-ai/)
- [Reddit](https://www.reddit.com/r/bmux/)

<p>
  <strong>WeChat:</strong> Escaneie o código QR para entrar na comunidade.<br />
  <img src="./docs/assets/wechat-community-qr.jpg" alt="Código QR do WeChat para entrar na comunidade bmux" width="240" />
</p>

## Edição do Fundador

O bmux é gratuito, open source, e sempre será. Se você gostaria de apoiar o desenvolvimento e ter acesso antecipado ao que está por vir:

**[Obter Edição do Fundador](https://buy.stripe.com/3cI00j2Ld0it5OU33r5EY0q)**

- **Solicitações de recursos/correções de bugs priorizadas**
- **Acesso antecipado: bmux AI que te dá contexto sobre cada workspace, aba e painel**
- **Acesso antecipado: app iOS com terminais sincronizados entre desktop e celular**
- **Acesso antecipado: VMs na nuvem**
- **Acesso antecipado: Modo de voz**
- **Meu iMessage/WhatsApp pessoal**

## Licença

bmux é open source sob [GPL-3.0-or-later](LICENSE).

Se sua organização não puder cumprir a GPL, uma licença comercial está disponível. Entre em contato com [founders@manaflow.com](mailto:founders@manaflow.com) para detalhes.
