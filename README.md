# sebas.dot

## Instalacion Linux

Ejecuta onboarding para clonar/actualizar el repo y correr la instalacion:

```bash
bash scripts/onboarding.sh --mode safe
```

Por defecto usa el target `$HOME/.sebas.dot`.
En Linux, `scripts/install.sh` usa `Brewfile.linux` si existe; si no, hace fallback a `Brewfile` con warning.
