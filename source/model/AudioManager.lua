-- =============================================================
-- model/AudioManager.lua  — v1.0
-- Sistema de música dinámica para Plomero Díaz.
--
-- Carga "After_the_Final_Coin.mp3" y lo reproduce en loop
-- durante STATE_GAMEPLAY. Vincula el Rate de reproducción al
-- nivel del agua: a mayor agua (pánico) → música más rápida.
--
-- API pública:
--   AudioManager.init()
--   AudioManager.update(water, isPanic)
--   AudioManager.startMusic()
--   AudioManager.stopMusic()
--   AudioManager.pauseMusic()
-- =============================================================

AudioManager = {}

-- ── Constantes ────────────────────────────────────────────────
local MUSIC_PATH      <const> = "assets/music/After_the_Final_Coin"
local RATE_NORMAL     <const> = 1.0    -- velocidad estándar
local RATE_TENSION    <const> = 1.25   -- agua entre 60–79 %
local RATE_PANIC      <const> = 1.55   -- agua ≥ 80 % (SUB_PANIC)

-- Suavizado: el Rate no cambia de golpe, sino gradualmente.
-- Se mueve RATE_LERP_SPEED por frame hacia el target.
local RATE_LERP_SPEED <const> = 0.04

-- ── Estado interno ────────────────────────────────────────────
local player     = nil     -- fileplayer
local loaded     = false
local currentRate = RATE_NORMAL
local targetRate  = RATE_NORMAL
local musicOn    = false

-- ── Carga lazy ────────────────────────────────────────────────
local function ensureLoaded()
    if loaded then return end
    player = playdate.sound.fileplayer.new(MUSIC_PATH)
    if player then
        player:setLoopRange(0)   -- loop desde el inicio
        loaded = true
    end
end

-- ── API pública ───────────────────────────────────────────────

function AudioManager.init()
    currentRate = RATE_NORMAL
    targetRate  = RATE_NORMAL
    musicOn     = false
    -- No cargamos el archivo aquí; lo hacemos lazy en startMusic()
    -- para no retrasar el init del juego.
end

function AudioManager.startMusic()
    ensureLoaded()
    if not loaded or not player then return end
    -- [FIX v1.1] Solo arrancar si no está ya reproduciendo.
    -- NO reseteamos el rate aquí: si venimos de un cambio de nivel,
    -- el rate puede ya estar elevado (pánico del nivel anterior)
    -- y el lerp en update() lo llevará suavemente al valor correcto.
    if not player:isPlaying() then
        player:play(0)   -- 0 = loop infinito en Playdate SDK
        currentRate = RATE_NORMAL
        targetRate  = RATE_NORMAL
        player:setRate(RATE_NORMAL)
    end
    musicOn = true
end

function AudioManager.stopMusic()
    if player and player:isPlaying() then
        player:stop()
    end
    musicOn = false
end

function AudioManager.pauseMusic()
    if player and player:isPlaying() then
        player:pause()
    end
    musicOn = false
end

-- ── Update: llamar cada frame durante STATE_GAMEPLAY ─────────
-- water    = Toilet.getWaterLevel() (0–100)
-- isPanic  = (subState == SUB_PANIC)
function AudioManager.update(water, isPanic)
    if not loaded or not player then return end

    -- Calcular el rate objetivo según el nivel de agua
    if isPanic or water >= 80 then
        targetRate = RATE_PANIC
    elseif water >= 60 then
        targetRate = RATE_TENSION
    else
        targetRate = RATE_NORMAL
    end

    -- Lerp suave hacia el target (evita cambios bruscos)
    if math.abs(currentRate - targetRate) > 0.001 then
        if currentRate < targetRate then
            currentRate = math.min(currentRate + RATE_LERP_SPEED, targetRate)
        else
            currentRate = math.max(currentRate - RATE_LERP_SPEED, targetRate)
        end
        player:setRate(currentRate)
    end
end
