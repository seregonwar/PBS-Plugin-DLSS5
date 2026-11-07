-- SPDX-License-Identifier: MIT
-- DLSS 5 runtime companion for PBS Studio (schema v5 script plugin).
--
-- This plugin verifies the NVIDIA DLSS 5 "Neural Rendering" runtime package
-- (nvngx_dlssnr.dll) that the operator points it at, remembers the operator's
-- upscaling preferences and reports the state of the stream. It never loads,
-- maps or executes the library: PBS Studio has no native plugin loader, and the
-- sandbox exposes only pbs.file.probe (existence, size, SHA-256).

local DEFAULT_PATH = [[C:\Program Files\NVIDIA Corporation\DLSS\nvngx_dlssnr.dll]]
local MODES = { "Quality", "Balanced", "Performance", "Ultra performance" }
local PERMISSION_HINT = "Grant runtime.script, api.host, api.store, api.ui and api.file."

local function state(key, fallback)
  local value = pbs.store.get(key)
  if value == nil then
    return fallback
  end
  return value
end

local function detect_version(path)
  local version = string.match(path or "", "(%d+%.%d+%.%d+)")
  if version == nil then
    return "not in the file name"
  end
  return version
end

local function human_size(bytes)
  if bytes >= 1024 * 1024 then
    return string.format("%.1f MiB", bytes / (1024 * 1024))
  end
  if bytes >= 1024 then
    return string.format("%.1f KiB", bytes / 1024)
  end
  return tostring(bytes) .. " bytes"
end

local function verify(path)
  local ok, info = pcall(pbs.file.probe, path, true)
  if not ok or info == nil then
    pbs.log("warn", "The runtime path could not be read.")
    return nil
  end
  local report = {
    exists = info.exists and info.regular or false,
    size = info.size or 0,
    sha256 = info.sha256 or "",
    version = detect_version(path),
  }
  pbs.store.set("runtime_ok", report.exists and 1 or 0)
  pbs.store.set("runtime_version", report.version)
  pbs.store.set("runtime_size", report.size)
  pbs.store.set("runtime_sha256", report.sha256)
  pbs.store.set("checks", state("checks", 0) + 1)
  return report
end

local function summary()
  if state("runtime_ok", 0) ~= 1 then
    return "No verified DLSS 5 runtime yet. Point PBS Studio at nvngx_dlssnr.dll and verify it once."
  end
  return "DLSS 5 runtime " .. state("runtime_version", "?") .. " - " ..
         human_size(state("runtime_size", 0))
end

pbs.ui.panel("dlss5", "DLSS 5 runtime", function()
  local verified = state("runtime_ok", 0) == 1
  pbs.ui.badge(verified and "Runtime package verified" or "Runtime package not verified",
               verified and "good" or "warn")
  pbs.ui.text(summary())

  pbs.ui.metric("stream.resolution", "Stream")
  pbs.ui.metric("stream.decoder", "Decoder")
  pbs.ui.metric("graphics.device", "Graphics device")
  pbs.ui.metric("stream.enhancement_ms", "Native enhancement")

  local path = pbs.ui.input("path", "nvngx_dlssnr.dll path", state("path", DEFAULT_PATH))
  pbs.store.set("path", path)
  pbs.ui.note("Absolute path only. The plugin reads the size and SHA-256; it never loads the library.")

  if pbs.ui.button("verify", "Verify DLSS package") then
    local report = verify(path)
    if report == nil then
      pbs.notify("DLSS 5", "That path cannot be read.")
    elseif report.exists then
      pbs.notify("DLSS 5", "Verified " .. report.version .. " - " .. human_size(report.size))
    else
      pbs.notify("DLSS 5", "No regular nvngx_dlssnr.dll at that path.")
    end
  end

  if verified then
    local digest = state("runtime_sha256", "")
    if digest ~= "" then
      pbs.ui.note("SHA-256 " .. string.sub(digest, 1, 32) .. "...")
    end
    pbs.ui.text("Checks performed: " .. state("checks", 0))
  end

  pbs.ui.separator()
  local mode = pbs.ui.combo("mode", "Preferred upscaling mode", MODES, state("mode", 0))
  pbs.store.set("mode", mode)
  local frame_generation = pbs.ui.checkbox("frame_generation",
      "Frame generation preferred", state("frame_generation", 0) == 1)
  pbs.store.set("frame_generation", frame_generation and 1 or 0)
  local warn = pbs.ui.checkbox("warn_decoder",
      "Warn when the decoder is not a good DLSS candidate",
      state("warn_decoder", 1) == 1)
  pbs.store.set("warn_decoder", warn and 1 or 0)
  pbs.ui.note("Mode: " .. MODES[mode + 1] .. " - frame generation " ..
              (frame_generation and "preferred" or "off") .. ".")

  if warn and verified and pbs.metric("console.connected") ~= true then
    pbs.ui.badge("No console connected: preferences are stored but unused right now.", "info")
  end

  pbs.ui.separator()
  if pbs.ui.button("streaming", "Open streaming settings") then
    if not pbs.navigate("open.settings.streaming") then
      pbs.notify("DLSS 5", "Streaming settings are not available in this build.")
    end
  end
  if pbs.ui.button("reset", "Forget saved checks") then
    for _, key in ipairs({ "runtime_ok", "runtime_version", "runtime_size",
                           "runtime_sha256", "checks" }) do
      pbs.store.set(key, nil)
    end
    pbs.notify("DLSS 5", "Saved checks cleared.")
  end

  pbs.ui.note("PBS Studio does not load native libraries. This plugin prepares and " ..
              "verifies the DLSS 5 runtime and your preferences; frame-level NGX " ..
              "processing needs a host renderer hook that is not part of this plugin.")
end, "Verifies the NVIDIA DLSS 5 runtime package and remembers upscaling preferences.")

if select("#", pbs.api_version) > 0 and pbs.api_version ~= 2 then
  pbs.log("error", "This plugin expects script API 2 (" .. PERMISSION_HINT .. ")")
end
