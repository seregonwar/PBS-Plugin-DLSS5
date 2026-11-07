# DLSS 5 runtime companion for PBS Studio

A public **PBS-SDK schema v5** plugin for [PBS Studio](https://github.com/seregonwar/PBS-Studio).
It is the first published script plugin: the Lua program travels inside the
manifest, and PBS Studio runs it in its sandbox with only the permissions you
approve.

The plugin is a **runtime companion** for the NVIDIA DLSS 5 *Neural Rendering*
package — the `nvngx_dlssnr.dll` build shipped as
`nvngx_dlssnr_compat-fp16-310.9.16-cuda13.4.3`:

- verifies the DLL the operator selects: existence, regular-file status, size,
  SHA-256 and the version encoded in its file name;
- remembers the preferred upscaling mode and frame-generation preference in the
  plugin's own 8 KiB settings store;
- shows live stream facts (resolution, decoder, graphics device, native
  enhancement time) next to the package status;
- warns when no console is connected, offers the streaming settings shortcut and
  clears its stored checks on request.

## Status and honest limits

PBS Studio has **no native plugin loader**. A schema v5 plugin is sandboxed Lua:
it has no file writes, no process control, no network and no way to load a DLL.
So this plugin **does not upscale frames**. It prepares and validates the DLSS 5
runtime package and the operator's settings, and it reports readiness, which is
what a script plugin can do today. Applying NGX itself needs a host renderer
hook (device, command list, motion vectors and depth) that is not part of the
plugin contract; when PBS Studio grows an enhancement hook, this plugin will
configure it instead of only describing it.

The DLL is **never redistributed** here: downloading NVIDIA's runtime is the
operator's own step, and `.gitignore` rejects `*.dll`.

## Install

1. Build the manifest (or use the committed `dist/plugin.json`):

   ```sh
   python tools/build.py
   ```

2. In PBS Studio open **Home → Plugins → Add a plugin**, choose
   `dist/plugin.json`, review the permissions and approve it.
3. Grant the five requested permissions, then open the **DLSS 5 runtime** panel.
4. Paste the absolute path of your `nvngx_dlssnr.dll` and press
   **Verify DLSS package**.

### Permissions

| Permission | Why |
| --- | --- |
| `runtime.script` | Runs this plugin's Lua source in PBS Studio's sandbox. |
| `api.host` | Reads stream metrics and opens approved settings pages. |
| `api.store` | Saves the path, mode and last verification result. |
| `api.ui` | Builds this plugin's panel and shows its short messages. |
| `api.file` | Probes the single DLL path you type: size and SHA-256 only. |

Revoke any permission to stop that capability immediately; turning the plugin
off stops its VM.

## Quickstart (Italiano)

1. `python tools/build.py` genera `dist/plugin.json`.
2. In PBS Studio: **Home → Plugins → Aggiungi un plugin**, seleziona
   `dist/plugin.json`, controlla i permessi e approva.
3. Concedi i cinque permessi, apri il pannello **DLSS 5 runtime**, incolla il
   percorso assoluto di `nvngx_dlssnr.dll` e premi **Verify DLSS package**.
4. Il plugin verifica il pacchetto (dimensione, SHA-256, versione nel nome) e
   salva le preferenze. **Non applica DLSS ai frame**: PBS Studio non carica
   librerie native; l'upscaling NGX richiede un hook del renderer lato host.

## Development

```sh
python tools/build.py
python -m pip install jsonschema
# validate against the published v5 schema
git clone --depth 1 https://github.com/seregonwar/PBS-SDK /tmp/PBS-SDK
python /tmp/PBS-SDK/scripts/validate.py dist/plugin.json
```

The runtime itself is covered by the host's `pbs_plugin_script` suite (sandbox
escapes, instruction and memory limits, permission denial, storage caps, widget
budgets, click delivery and file probing).

## Layout

```
manifest.base.json     metadata, permissions, schema/API versions
src/plugin.lua         the plugin program (reviewed source of truth)
tools/build.py         embeds the source and writes dist/plugin.json
dist/plugin.json       installable artifact imported by PBS Studio
```

## License

MIT. NVIDIA, DLSS and nvngx_dlssnr are trademarks of NVIDIA Corporation; this
project is not affiliated with or endorsed by NVIDIA.
