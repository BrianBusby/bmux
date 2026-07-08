> Esta traducción fue generada por Claude. Si tienes sugerencias de mejora, abre un PR.

<h1 align="center">bmux</h1>
<p align="center">Un terminal macOS basado en Ghostty con pestañas verticales y notificaciones para agentes de programación con IA</p>

<p align="center">
  <a href="https://github.com/manaflow-ai/bmux/releases/latest/download/bmux-macos.dmg">
    <img src="../assets/macos-badge.png" alt="Descargar bmux para macOS" width="180" />
  </a>
</p>

<p align="center">
  <a href="../../README.md">English</a> | <a href="README.ja.md">日本語</a> | <a href="README.vi.md">Tiếng Việt</a> | <a href="README.zh-CN.md">简体中文</a> | <a href="README.zh-TW.md">繁體中文</a> | <a href="README.ko.md">한국어</a> | <a href="README.de.md">Deutsch</a> | Español | <a href="README.fr.md">Français</a> | <a href="README.it.md">Italiano</a> | <a href="README.da.md">Dansk</a> | <a href="README.pl.md">Polski</a> | <a href="README.ru.md">Русский</a> | <a href="README.bs.md">Bosanski</a> | <a href="README.ar.md">العربية</a> | <a href="README.no.md">Norsk</a> | <a href="README.pt-BR.md">Português (Brasil)</a> | <a href="README.th.md">ไทย</a> | <a href="README.tr.md">Türkçe</a> | <a href="README.km.md">ភាសាខ្មែរ</a> | <a href="README.uk.md">Українська</a>
</p>

<p align="center">
  <a href="https://x.com/manaflowai"><img src="https://img.shields.io/badge/@manaflow-555?logo=x" alt="X / Twitter" /></a>
  <a href="https://discord.gg/xsgFEVrWCZ"><img src="https://img.shields.io/badge/Discord-555?logo=discord" alt="Discord" /></a>
  <a href="https://github.com/manaflow-ai/bmux"><img src="https://img.shields.io/github/stars/manaflow-ai/bmux?style=flat&logo=github&label=stars&color=4c71f2" alt="GitHub stars" /></a>
</p>

<p align="center">
  <img src="../assets/main-first-image.png" alt="Captura de pantalla de bmux" width="900" />
</p>

<p align="center">
  <a href="https://www.youtube.com/watch?v=i-WxO5YUTOs">▶ Video de demostración</a> · <a href="https://bmux.com/blog/zen-of-bmux">The Zen of bmux</a>
</p>

## Características

<table>
<tr>
<td width="40%" valign="middle">
<h3>Anillos de notificación</h3>
Los paneles obtienen un anillo azul y las pestañas se iluminan cuando los agentes de programación necesitan tu atención
</td>
<td width="60%">
<img src="../assets/notification-rings.png" alt="Anillos de notificación" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>Panel de notificaciones</h3>
Ve todas las notificaciones pendientes en un solo lugar, salta a la más reciente no leída
</td>
<td width="60%">
<img src="../assets/sidebar-notification-badge.png" alt="Insignia de notificación en la barra lateral" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>Navegador integrado</h3>
Divide un navegador junto a tu terminal con una API programable portada de <a href="https://github.com/vercel-labs/agent-browser">agent-browser</a>
</td>
<td width="60%">
<img src="../assets/built-in-browser.png" alt="Navegador integrado" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>Pestañas verticales + horizontales</h3>
La barra lateral muestra la rama de git, el estado/número del PR vinculado, el directorio de trabajo, los puertos en escucha y el texto de la última notificación. Divide horizontal y verticalmente.
</td>
<td width="60%">
<img src="../assets/vertical-horizontal-tabs-and-splits.png" alt="Pestañas verticales y paneles divididos" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>SSH</h3>
<code>bmux ssh user@remote</code> crea un espacio de trabajo para una máquina remota. Los paneles del navegador se enrutan a través de la red remota, así que localhost simplemente funciona. Arrastra una imagen a una sesión remota para subirla vía scp.
</td>
<td width="60%">
<img src="../assets/ssh.png" alt="bmux SSH" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>Claude Code Teams</h3>
<code>bmux claude-teams</code> ejecuta el modo de compañeros de equipo de Claude Code con un solo comando. Los compañeros aparecen como divisiones nativas con metadatos en la barra lateral y notificaciones. No se requiere tmux.
</td>
<td width="60%">
<img src="../assets/claude-code-teams.png" alt="Claude Code Teams" width="100%" />
</td>
</tr>
</table>

- **Importación de navegador** — Importa cookies, historial y sesiones de Chrome, Firefox, Arc y más de 20 navegadores para que los paneles del navegador inicien autenticados
- **Comandos personalizados** — Define acciones específicas del proyecto en [`bmux.json`](https://bmux.com/docs/custom-commands) que se lanzan desde la paleta de comandos
- **Programable** — CLI y API de socket para crear espacios de trabajo, dividir paneles, enviar pulsaciones de teclas y automatizar el navegador
- **App nativa de macOS** — Construida con Swift y AppKit, no con Electron. Inicio rápido, bajo consumo de memoria.
- **Compatible con Ghostty** — Lee tu configuración existente en `~/.config/ghostty/config` para temas, fuentes y colores
- **Aceleración por GPU** — Impulsado por libghostty para un renderizado fluido
- **Atajos de teclado** — [Atajos extensos](https://bmux.com/docs/keyboard-shortcuts) para espacios de trabajo, divisiones, navegador y más
- **Código abierto** — Gratuito y con licencia GPL

## Instalación

### DMG (recomendado)

<a href="https://github.com/manaflow-ai/bmux/releases/latest/download/bmux-macos.dmg">
  <img src="../assets/macos-badge.png" alt="Descargar bmux para macOS" width="180" />
</a>

Abre el `.dmg` y arrastra bmux a tu carpeta de Aplicaciones. bmux se actualiza automáticamente a través de Sparkle, así que solo necesitas descargarlo una vez.

### Homebrew

```bash
brew tap manaflow-ai/bmux
brew install --cask bmux
```

Para actualizar más tarde:

```bash
brew upgrade --cask bmux
```

En el primer inicio, macOS puede pedirte que confirmes la apertura de una app de un desarrollador identificado. Haz clic en **Abrir** para continuar.

## ¿Por qué bmux?

Ejecuto muchas sesiones de Claude Code y Codex en paralelo. Estaba usando Ghostty con un montón de paneles divididos y dependía de las notificaciones nativas de macOS para saber cuándo un agente me necesitaba. Pero el cuerpo de la notificación de Claude Code siempre es solo "Claude is waiting for your input" sin contexto, y con suficientes pestañas abiertas ya ni siquiera podía leer los títulos.

Probé algunos orquestadores de programación, pero la mayoría eran aplicaciones Electron/Tauri y el rendimiento me molestaba. Además, simplemente prefiero la terminal ya que los orquestadores con GUI te encierran en su flujo de trabajo. Así que construí bmux como una app nativa de macOS en Swift/AppKit. Usa libghostty para el renderizado del terminal y lee tu configuración existente de Ghostty para temas, fuentes y colores.

Las principales adiciones son la barra lateral y el sistema de notificaciones. La barra lateral tiene pestañas verticales que muestran la rama de git, el estado/número del PR vinculado, el directorio de trabajo, los puertos en escucha y el texto de la última notificación para cada espacio de trabajo. El sistema de notificaciones detecta secuencias de terminal (OSC 9/99/777) y tiene un CLI (`bmux notify`) que puedes conectar a los hooks de agentes para Claude Code, OpenCode, etc. Cuando un agente está esperando, su panel obtiene un anillo azul y la pestaña se ilumina en la barra lateral, para que pueda saber cuál me necesita entre divisiones y pestañas. Cmd+Shift+U salta a la notificación no leída más reciente.

El navegador integrado tiene una API programable portada de [agent-browser](https://github.com/vercel-labs/agent-browser). Los agentes pueden capturar el árbol de accesibilidad, obtener referencias de elementos, hacer clic, rellenar formularios y ejecutar JS. Puedes dividir un panel de navegador junto a tu terminal y hacer que Claude Code interactúe directamente con tu servidor de desarrollo.

Todo es programable a través del CLI y la API de socket — crear espacios de trabajo/pestañas, dividir paneles, enviar pulsaciones de teclas, abrir URLs en el navegador.

## The Zen of bmux

bmux no prescribe cómo los desarrolladores deben usar sus herramientas. Es un terminal y navegador con un CLI, y el resto depende de ti.

bmux es un primitivo, no una solución. Te da un terminal, un navegador, notificaciones, espacios de trabajo, divisiones, pestañas y un CLI para controlarlo todo. bmux no te obliga a usar los agentes de programación de una manera específica. Lo que construyas con los primitivos es tuyo.

Los mejores desarrolladores siempre han construido sus propias herramientas. Nadie ha descubierto la mejor manera de trabajar con agentes todavía, y los equipos que construyen productos cerrados tampoco. Los desarrolladores más cercanos a sus propias bases de código lo descubrirán primero.

Dale a un millón de desarrolladores primitivos componibles y encontrarán colectivamente los flujos de trabajo más eficientes más rápido de lo que cualquier equipo de producto podría diseñar de arriba hacia abajo.

## Documentación

Para más información sobre cómo configurar bmux, [visita nuestra documentación](https://bmux.com/docs/getting-started?utm_source=readme).

## Atajos de teclado

### Espacios de trabajo

| Atajo | Acción |
|----------|--------|
| ⌘ N | Nuevo espacio de trabajo |
| ⌘ 1–8 | Ir al espacio de trabajo 1–8 |
| ⌘ 9 | Ir al último espacio de trabajo |
| ⌃ ⌘ ] | Siguiente espacio de trabajo |
| ⌃ ⌘ [ | Espacio de trabajo anterior |
| ⌘ ⇧ W | Cerrar espacio de trabajo |
| ⌘ ⇧ R | Renombrar espacio de trabajo |
| ⌥ ⌘ E | Editar descripción del espacio de trabajo |
| ⌘ B | Alternar barra lateral |
| ⌥ ⌘ B | Alternar barra lateral derecha |
| ⌘ ⇧ E | Alternar foco de la barra lateral derecha |

### Superficies

| Atajo | Acción |
|----------|--------|
| ⌘ T | Nueva superficie |
| ⌘ ⇧ ] | Siguiente superficie |
| ⌘ ⇧ [ | Superficie anterior |
| ⌃ Tab | Siguiente superficie |
| ⌃ ⇧ Tab | Superficie anterior |
| ⌃ 1–8 | Ir a la superficie 1–8 |
| ⌃ 9 | Ir a la última superficie |
| ⌘ W | Cerrar superficie |

### Paneles divididos

| Atajo | Acción |
|----------|--------|
| ⌘ D | Dividir a la derecha |
| ⌘ ⇧ D | Dividir hacia abajo |
| ⌥ ⌘ ← → ↑ ↓ | Enfocar panel direccionalmente |
| ⌘ ⇧ H | Destellar panel enfocado |

### Navegador

Los atajos de herramientas de desarrollo del navegador siguen los valores predeterminados de Safari y son personalizables en `Ajustes → Atajos de teclado`.
Los atajos de navegación de la paleta de comandos, incluido ⌃ P, también son personalizables y se pueden borrar para que la pulsación llegue al terminal activo.

| Atajo | Acción |
|----------|--------|
| ⌘ ⇧ L | Abrir navegador en división |
| ⌘ L | Enfocar barra de direcciones |
| ⌘ [ | Atrás |
| ⌘ ] | Adelante |
| ⌘ R | Recargar página |
| ⌥ ⌘ I | Alternar herramientas de desarrollo (predeterminado de Safari) |
| ⌥ ⌘ C | Mostrar consola de JavaScript (predeterminado de Safari) |

### Notificaciones

| Atajo | Acción |
|----------|--------|
| ⌘ I | Mostrar panel de notificaciones |
| ⌘ ⇧ U | Ir a la última no leída |
| ⌥ ⌘ U | Alternar estado no leído del elemento actual |
| ⌃ ⌘ U | Marcar el elemento actual como la no leída más antigua y saltar a la siguiente más reciente no leída |

### Buscar

| Atajo | Acción |
|----------|--------|
| ⌘ F | Buscar |
| ⌘ ⇧ F | Buscar en el directorio |
| ⌘ G / ⌥ ⌘ G | Buscar siguiente / anterior |
| ⌥ ⌘ ⇧ F | Ocultar barra de búsqueda |
| ⌘ E | Usar selección para buscar |

### Terminal

| Atajo | Acción |
|----------|--------|
| ⌘ K | Limpiar historial de desplazamiento |
| ⌘ C | Copiar (con selección) |
| ⌘ V | Pegar |
| ⌘ + / ⌘ - | Aumentar / disminuir tamaño de fuente |
| ⌘ 0 | Restablecer tamaño de fuente |

### Ventana

| Atajo | Acción |
|----------|--------|
| ⌘ ⇧ N | Nueva ventana |
| ⌘ ⇧ O | Reabrir sesión anterior |
| ⌘ , | Ajustes |
| ⌘ ⇧ , | Recargar configuración |
| ⌘ Q | Salir |

## Compilaciones nocturnas

[Descargar bmux NIGHTLY](https://github.com/manaflow-ai/bmux/releases/download/nightly/bmux-nightly-macos.dmg)

bmux NIGHTLY es una app separada con su propio bundle ID, por lo que se ejecuta junto a la versión estable. Se compila automáticamente desde el último commit de `main` y se actualiza automáticamente a través de su propio feed de Sparkle.

Reporta errores de nightly en [GitHub Issues](https://github.com/manaflow-ai/bmux/issues) o en [#nightly-bugs en Discord](https://discord.gg/xsgFEVrWCZ).

## Restauración de sesión

Al salir, bmux guarda la sesión actual. Al relanzar, bmux restaura el estado
que pertenece a la app:
- Diseño de ventanas/espacios de trabajo/paneles
- Directorios de trabajo
- Historial de desplazamiento del terminal (mejor esfuerzo)
- URL del navegador e historial de navegación

bmux no guarda puntos de control de procesos activos arbitrarios. tmux, vim, shells y
apps de terminal no compatibles se vuelven a abrir como terminales normales.

Las sesiones de agentes compatibles pueden reanudarse cuando los hooks han guardado un ID
de sesión nativo. Instala los hooks después de instalar el CLI del agente para que su
binario esté en el `PATH`:

```bash
bmux hooks setup
bmux hooks setup codex
bmux hooks setup --agent opencode
```

`bmux hooks setup` instala los agentes compatibles que encuentra e imprime un resumen
de los agentes omitidos. Las integraciones de reanudación compatibles incluyen Claude Code, Codex,
Grok, OpenCode, Pi, Amp, Cursor CLI, Gemini, Rovo Dev, Copilot, CodeBuddy,
Factory y Qoder. Claude Code es gestionado por el wrapper de Claude de bmux cuando la
integración de Claude está habilitada en Ajustes.

Los usuarios avanzados y las integraciones pueden asociar un comando de reanudación personalizado a la
superficie de terminal actual. Esto es útil para herramientas con su propio estado duradero,
como sesiones tmux o CLIs de agentes personalizados:

```bash
bmux surface resume set --kind tmux --checkpoint work --shell "tmux attach -t work"
bmux surface resume show --json
bmux surface resume clear --checkpoint work
```

La asociación queda ligada a la superficie de bmux. Las asociaciones creadas por el CLI
público o el socket se guardan para inspección y restauración manual, a menos que apruebes un
prefijo de comando firmado para restauración automática. Los prefijos aprobados también quedan ligados
al directorio de trabajo y a los valores exactos del entorno, cuando están presentes. Revisa o edita
las aprobaciones en **Ajustes > Terminal > Comandos de reanudación**. bmux solo ejecuta automáticamente
las asociaciones de reanudación que marca como confiables, como las asociaciones tmux detectadas en procesos
activos o los prefijos aprobados por el usuario. Las claves de entorno sensibles, como tokens, contraseñas,
secretos y claves de API, se descartan antes de guardar una asociación de reanudación.

Para mantener los terminales de agentes restaurados inactivos en lugar de ejecutar automáticamente sus comandos de reanudación,
desactiva **Ajustes > Terminal > Reanudar sesiones de agentes al reabrir** o establece esto en
`~/.config/bmux/bmux.json`:

```json
{
  "terminal": {
    "autoResumeAgentSessions": false
  }
}
```

Esto solo desactiva los comandos de reanudación automática de agentes. bmux sigue restaurando el diseño guardado,
los directorios de trabajo, el historial de desplazamiento y el historial del navegador.

Si necesitas volver a aplicar manualmente la última instantánea guardada, usa:
- `Archivo > Reabrir sesión anterior`
- `⌘ ⇧ O`
- `bmux restore-session`

Internamente, bmux escribe una instantánea versionada en
`~/Library/Application Support/bmux/` y los hooks de los agentes escriben las asignaciones de sesión
en `~/.bmuxterm/`. Al restaurar, bmux reconstruye primero el diseño y luego ejecuta el
comando de reanudación nativo del agente compatible cuando la reanudación automática de agentes está habilitada.

Lee la guía completa en <https://bmux.com/docs/session-restore>.

## FAQ

### ¿Cómo se relaciona bmux con Ghostty?

bmux no es un fork de Ghostty. Usa [libghostty](https://github.com/ghostty-org/ghostty) como biblioteca para el renderizado del terminal, de la misma manera que las apps usan WebKit para las vistas web. Ghostty es un terminal independiente; bmux es una app diferente construida sobre su motor de renderizado.

### ¿Qué plataformas soporta?

Solo macOS, por ahora. bmux es una app nativa de Swift + AppKit.

### ¿Hay una app de iOS?

Sí, en beta. Empareja tu iPhone con tu Mac desde la ventana de Mobile Connect y conéctate a tus terminales desde tu teléfono, con reenvío opcional de las notificaciones del terminal. Se distribuye en TestFlight como bmux BETA. Consulta la [documentación de iOS](https://bmux.com/docs/ios).

### ¿Con qué agentes de programación funciona bmux?

Con todos. bmux es un terminal, así que cualquier agente que se ejecute en un terminal funciona de inmediato: Claude Code, Codex, OpenCode, Gemini CLI, Kiro, Aider, Goose, Amp, Cline, Cursor Agent y cualquier otra cosa que puedas lanzar desde la línea de comandos.

### ¿Puede bmux orquestar múltiples agentes y subagentes?

Sí. Cuando un agente genera subagentes o compañeros de equipo, bmux los convierte en paneles y divisiones nativos en lugar de procesos ocultos en segundo plano. Soporta [Claude Code teams](https://bmux.com/docs/agent-integrations/claude-code-teams) y la orquestación multimodelo de [oh-my-opencode](https://bmux.com/docs/agent-integrations/oh-my-opencode), de modo que cada agente de una ejecución es visible y controlable.

### ¿Puedo usar bmux con máquinas remotas?

Sí. Abre espacios de trabajo a través de SSH y conéctate a sesiones tmux remotas, para que los agentes puedan ejecutarse en un host remoto mientras los manejas desde bmux. Consulta [SSH y remoto](https://bmux.com/docs/ssh).

### ¿Cómo funcionan las notificaciones?

Cuando un proceso necesita atención, bmux muestra anillos de notificación alrededor de los paneles, insignias de no leídas en la barra lateral, un popover de notificaciones y una notificación de escritorio de macOS. Estas se activan automáticamente mediante secuencias de escape de terminal estándar (OSC 9/99/777), o puedes dispararlas con el [CLI de bmux](https://bmux.com/docs/notifications#cli-usage) y los [hooks de agentes](https://bmux.com/docs/notifications#integration-examples). Cualquier agente que soporte hooks u OSC funciona, incluidos Claude Code, Codex, OpenCode y pi.

### ¿Es bmux programable?

Sí. Cada acción está disponible a través del CLI de bmux y un socket Unix: crear espacios de trabajo, abrir paneles divididos, enviar entrada, leer el contenido de la pantalla, tomar capturas y manejar el navegador integrado. Consulta la [referencia del CLI](https://bmux.com/docs/api) y la documentación de [automatización del navegador](https://bmux.com/docs/browser-automation).

### ¿Qué puede hacer el navegador integrado?

bmux puede dividir un panel de navegador real junto a tu terminal, y es totalmente programable: navegar, capturar el DOM, hacer clic, escribir, ejecutar JavaScript y leer la actividad de consola y de red a través de la misma API de socket. Los agentes lo usan para verificar sus propios cambios web sin salir de bmux. Consulta [automatización del navegador](https://bmux.com/docs/browser-automation).

### ¿bmux tiene skills?

Sí. Las skills son flujos de trabajo reutilizables que puedes dar a cualquier agente que se ejecute en bmux, para cosas como control del CLI, automatización de espacios de trabajo, ajustes y superficies de navegador. Explora la colección abierta en [bmux-skills](https://github.com/manaflow-ai/bmux-skills) o lee la [documentación de skills](https://bmux.com/docs/skills).

### ¿Puedo personalizar los atajos de teclado?

Las combinaciones de teclas del terminal se leen de tu archivo de configuración de Ghostty (`~/.config/ghostty/config`). Los atajos específicos de bmux (espacios de trabajo, divisiones, navegador, notificaciones) se pueden personalizar en Ajustes. Consulta los [atajos predeterminados](https://bmux.com/docs/keyboard-shortcuts) para ver la lista completa.

### ¿Puedo personalizar bmux?

Sí. El renderizado del terminal usa tu configuración de Ghostty, así que los temas, fuentes, colores y cursor se trasladan directamente. Los propios ajustes de bmux en `~/.config/bmux/bmux.json` controlan la barra lateral, la barra de pestañas, los paneles divididos y el comportamiento, y cada [atajo de teclado](https://bmux.com/docs/keyboard-shortcuts) es editable. Consulta [configuración](https://bmux.com/docs/configuration).

### ¿Se guardan mis sesiones?

Sí. bmux restaura tus ventanas, espacios de trabajo, paneles, directorios de trabajo e historial de desplazamiento al relanzar, y el estado sobrevive a un reinicio completo del ordenador, no solo a cerrar la app. Las sesiones de agentes como Claude Code, Codex y OpenCode también vuelven. Consulta [restauración de sesión](https://bmux.com/docs/session-restore).

### ¿Cómo se compara con tmux?

tmux es un multiplexor de terminal que se ejecuta dentro de cualquier terminal. bmux es una app nativa de macOS con GUI: pestañas verticales, paneles divididos, un navegador integrado y una API de socket, todo incorporado, sin necesidad de archivos de configuración ni teclas de prefijo. Dicho esto, mucha gente ejecuta felizmente bmux junto con SSH y tmux, y bmux puede conectarse a tus sesiones tmux remotas de forma nativa ([beta](https://bmux.com/docs/remote-tmux)).

### ¿Es bmux gratuito?

Sí, bmux es de uso gratuito. El código fuente está disponible en [GitHub](https://github.com/manaflow-ai/bmux).

### ¿Cómo puedo apoyar a bmux?

bmux es gratuito y de código abierto, y siempre lo será. Si quieres respaldar el desarrollo y obtener acceso anticipado a lo que viene, incluidos bmux AI, la app de iOS y las Cloud VMs, echa un vistazo a [bmux Founders Edition](https://github.com/manaflow-ai/bmux#founders-edition).

### ¿Tengo una solicitud de función o encontré un error?

Queremos saberlo. Abre una [issue](https://github.com/manaflow-ai/bmux/issues) o un [pull request](https://github.com/manaflow-ai/bmux/pulls) en GitHub, o [escríbenos por correo](mailto:founders@manaflow.com?subject=bmux%20feature%20request).

## Historial de estrellas

<a href="https://star-history.com/#manaflow-ai/bmux&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=manaflow-ai/bmux&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=manaflow-ai/bmux&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=manaflow-ai/bmux&type=Date" width="600" />
 </picture>
</a>

## Contribuir

Formas de participar:

- Síguenos en X para actualizaciones [@manaflowai](https://x.com/manaflowai), [@lawrencecchen](https://x.com/lawrencecchen) y [@austinywang](https://x.com/austinywang)
- Únete a la conversación en [Discord](https://discord.gg/xsgFEVrWCZ)
- Crea y participa en [GitHub issues](https://github.com/manaflow-ai/bmux/issues) y [discusiones](https://github.com/manaflow-ai/bmux/discussions)
- Cuéntanos qué estás construyendo con bmux

## Comunidad

- [Discord](https://discord.gg/xsgFEVrWCZ)
- [GitHub](https://github.com/manaflow-ai/bmux)
- [X / Twitter](https://twitter.com/manaflowai)
- [YouTube](https://www.youtube.com/channel/UCAa89_j-TWkrXfk9A3CbASw)
- [LinkedIn](https://www.linkedin.com/company/manaflow-ai/)
- [Reddit](https://www.reddit.com/r/bmux/)

<p>
  <strong>WeChat:</strong> Escanea el código QR para unirte a la comunidad.<br />
  <img src="./docs/assets/wechat-community-qr.jpg" alt="Código QR de WeChat para unirte a la comunidad de bmux" width="240" />
</p>

## Founder's Edition

bmux es gratuito, de código abierto, y siempre lo será. Si deseas apoyar el desarrollo y obtener acceso anticipado a lo que viene:

**[Obtener Founder's Edition](https://buy.stripe.com/3cI00j2Ld0it5OU33r5EY0q)**

- **Solicitudes de funciones/corrección de errores priorizadas**
- **Acceso anticipado: bmux AI que te da contexto sobre cada espacio de trabajo, pestaña y panel**
- **Acceso anticipado: app de iOS con terminales sincronizadas entre escritorio y teléfono**
- **Acceso anticipado: VMs en la nube**
- **Acceso anticipado: Modo de voz**
- **Mi iMessage/WhatsApp personal**

## Licencia

bmux es código abierto bajo [GPL-3.0-or-later](LICENSE).

Si su organización no puede cumplir con GPL, hay una licencia comercial disponible. Contacte a [founders@manaflow.com](mailto:founders@manaflow.com) para más detalles.
