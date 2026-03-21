# sebas.dot

## Instalacion Linux

Ejecuta onboarding para clonar/actualizar el repo y correr la instalacion:

```bash
bash scripts/onboarding.sh --mode safe
```

Por defecto usa el target `$HOME/.sebas.dot`.
En Linux, `scripts/install.sh` usa `Brewfile.linux` si existe; si no, hace fallback a `Brewfile` con warning.
El onboarding ahora deja listo: OpenCode, Claude Code (CLI), shell default zsh y sincronizacion de configs (atuin/zoxide/zellij/ghostty).

### Que hace onboarding

`scripts/onboarding.sh` ejecuta en orden:

1. Preflight (dependencias y reachability del repo).
2. Clone/pull idempotente del repo target.
3. `scripts/install.sh --dry-run`.
4. Instalacion real (`--no-delete-opencode` en modo `safe`).

`scripts/install.sh` cubre:

- Brew bundle (`Brewfile.linux` en Linux).
- Instalacion de Claude Code CLI via npm (`@anthropic-ai/claude-code`) si no existe `claude`.
- Registro de zsh en `/etc/shells` (si aplica) y cambio de shell default con `chsh`.
- Symlinks seguros de dotfiles sin borrar estilos/config existentes sin backup.
- Configuracion de Ghostty para usar zsh (`command = <ruta-zsh>`) sin tocar shaders/tema.
- Sync de OpenCode (`~/.config/opencode`) y validaciones de hooks de shell.

### Ubuntu (fresh setup)

1. Ejecuta onboarding desde el repo clonado:

```bash
bash scripts/onboarding.sh --mode safe
```

2. Abre una nueva terminal o recarga zsh para aplicar entorno y PATH:

```bash
exec zsh
```

3. Verifica que los links principales quedaron activos:

```bash
ls -la ~/.zshrc ~/.p10k.zsh ~/.config/nvim ~/.config/zellij ~/.config/atuin ~/.config/ghostty
```

### Troubleshooting Ubuntu

- Si `onboarding.sh` termina sin error pero la configuracion no carga, valida que `~/.zshrc` sea symlink al repo en `~/.sebas.dot`:

```bash
readlink ~/.zshrc
```

- Si tu shell por defecto no es zsh, cambiala y vuelve a iniciar sesion:

```bash
chsh -s "$(command -v zsh)"
```

- Si falta algun binario, revisa el log y ejecuta el comando sugerido por el instalador:

```bash
tail -n 50 ~/.local/state/sebas.dot/install.log
```

- Si falla la instalacion completa, revisa ambos logs para identificar fase y comando exacto:

```bash
tail -n 120 ~/.local/state/sebas.dot/onboarding.log
tail -n 120 ~/.local/state/sebas.dot/install.log
```

- Si `claude` no aparece en PATH despues de onboarding:

```bash
npm install -g @anthropic-ai/claude-code
command -v claude
```

- Si Ghostty no abre con zsh, valida la linea `command = ...zsh` en el config del repo/symlink:

```bash
grep '^command = ' ~/.config/ghostty/config
```
