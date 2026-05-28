-- =============================================================
-- model/Toilet.lua
-- Gestión del nivel de agua, drenaje y visualización del inodoro
-- Versión 2.0: Olas dinámicas ukiyo-e con clipRect, sin rectángulos
-- =============================================================

Toilet = {}

-- ── Layout desde configuración global ────────────────────────
local TOILET_X, TOILET_Y, TOILET_W, TOILET_H
local BOWL_X, BOWL_Y, BOWL_W, BOWL_H

-- ── Estado interno ────────────────────────────────────────────
local waterLevel     = 50   -- porcentaje 0–100
local pendingPenalty = 0    -- acumulador de penalizaciones de QTE

-- ── Imágenes ─────────────────────────────────────────────────
local toiletImg  = nil
local waveImgs   = {}   -- { wave_1, wave_2, wave_3 }
local imgLoaded  = false

-- ── Animación de olas ────────────────────────────────────────
-- Cada ola tiene velocidad de desplazamiento distinta (paralaje)
local waveOffsets = { 0, 0, 0 }
local WAVE_W      = 96    -- ancho de la textura de ola (debe coincidir con el asset)
local WAVE_H      = 32    -- alto de la textura de ola

-- Velocidades de desplazamiento (px/frame). Ola 1 = más rápida (superficial)
local WAVE_SPEEDS = { 1.2, 0.75, 0.40 }

-- Offset Y de cada ola dentro del bowl (0 = justo al ras del agua)
-- Ola 1 flota arriba, ola 3 queda abajo simulando profundidad
local WAVE_Y_OFFSETS = { -14, -6, 2 }

-- ── Partículas de splash ──────────────────────────────────────
-- Tabla de partículas activas: cada una es { x, y, vx, vy, life }
local splashParticles = {}
local MAX_PARTICLES   = 12

local function spawnSplash(cx, cy, count)
    count = count or 4
    for i = 1, count do
        if #splashParticles < MAX_PARTICLES then
            table.insert(splashParticles, {
                x    = cx + math.random(-8, 8),
                y    = cy,
                vx   = math.random(-2, 2) * 0.5,
                vy   = -math.random(1, 4) * 0.6,
                life = math.random(8, 16),
            })
        end
    end
end

local function updateParticles()
    for i = #splashParticles, 1, -1 do
        local p = splashParticles[i]
        p.x    = p.x + p.vx
        p.y    = p.y + p.vy
        p.vy   = p.vy + 0.25   -- gravedad
        p.life = p.life - 1
        if p.life <= 0 then
            table.remove(splashParticles, i)
        end
    end
end

local function drawParticles(gfx)
    gfx.setColor(gfx.kColorBlack)
    for _, p in ipairs(splashParticles) do
        local size = math.max(1, math.floor(p.life / 6))
        if size == 1 then
            gfx.drawPixel(math.floor(p.x), math.floor(p.y))
        else
            gfx.fillRect(math.floor(p.x) - 1, math.floor(p.y) - 1, size, size)
        end
    end
end

-- ── Carga de imágenes ────────────────────────────────────────
local function loadImages()
    if imgLoaded then return end
    imgLoaded = true
    toiletImg = playdate.graphics.image.new("assets/images/toilet")
    waveImgs[1] = playdate.graphics.image.new("assets/images/wave_1")
    waveImgs[2] = playdate.graphics.image.new("assets/images/wave_2")
    waveImgs[3] = playdate.graphics.image.new("assets/images/wave_3")
end

-- ── API pública ───────────────────────────────────────────────

function Toilet.init(level)
    -- Leer coordenadas del layout global
    TOILET_X = Layout.TOILET_X
    TOILET_Y = Layout.TOILET_Y
    TOILET_W = Layout.TOILET_W
    TOILET_H = Layout.TOILET_H
    BOWL_X   = Layout.BOWL_X
    BOWL_Y   = Layout.BOWL_Y
    BOWL_W   = Layout.BOWL_W
    BOWL_H   = Layout.BOWL_H

    -- El agua comienza más alta en niveles avanzados
    waterLevel      = math.min(20 + (level - 1) * 4, 55)
    pendingPenalty  = 0
    waveOffsets     = { 0, 0, 0 }
    splashParticles = {}
    loadImages()
end

function Toilet.getWaterLevel() return waterLevel end

-- Llamado por QTEManager cuando falla un QTE
function Toilet.addPenalty(penalty)
    pendingPenalty += penalty
    -- Generar splash en el centro de la taza
    spawnSplash(BOWL_X + math.floor(BOWL_W / 2), BOWL_Y + math.floor(BOWL_H * 0.4), 6)
end

-- Actualización principal (1 vez por frame)
-- level       : nivel actual (afecta velocidad de llenado)
-- drainAmount : agua a drenar por crank este frame
-- panicMult   : multiplicador de velocidad en pánico (1.5)
function Toilet.update(level, drainAmount, panicMult)
    local fillPerSec   = math.min(0.95 + (level - 1) * 0.15, 2.0)
    local fillPerFrame = fillPerSec / 30
    fillPerFrame *= panicMult

    local penaltyThisFrame = pendingPenalty
    pendingPenalty = 0

    waterLevel = waterLevel + fillPerFrame - drainAmount + penaltyThisFrame
    waterLevel = math.max(0, math.min(100, waterLevel))

    -- Actualizar offsets de olas (velocidad doble en pánico)
    local speedMult = (waterLevel >= 80) and 2.0 or 1.0
    for i = 1, 3 do
        waveOffsets[i] = (waveOffsets[i] + WAVE_SPEEDS[i] * speedMult) % WAVE_W
    end

    -- Actualizar partículas
    updateParticles()
end

-- ── Dibujo ────────────────────────────────────────────────────
function Toilet.draw()
    local gfx        = playdate.graphics
    local ms         = playdate.getCurrentTimeMilliseconds()
    local waterHeight = math.floor((waterLevel / 100) * BOWL_H)
    local waterY      = BOWL_Y + (BOWL_H - waterHeight)

    -- ── 1. Rellenar base de agua (color sólido) ──────────────
    if waterHeight > 0 then
        gfx.setColor(gfx.kColorBlack)
        -- Fondo negro del agua (completo)
        gfx.fillRect(BOWL_X, waterY, BOWL_W, waterHeight)
        -- Franja blanca interior (efecto de agua con volumen)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(BOWL_X + 2, waterY + 4, BOWL_W - 4, waterHeight - 4)
    end

    -- ── 2. Dibujar olas con clipRect ─────────────────────────
    if waterHeight > 0 then
        local isPanic = (waterLevel >= 80)

        -- En pánico, parpadear las olas (visibilidad alterna)
        local drawWaves = true
        if isPanic then
            drawWaves = (math.floor(ms / 120) % 2) == 0
        end

        if drawWaves then
            -- Aplicar máscara de recorte al interior del bowl
            gfx.setClipRect(BOWL_X, waterY, BOWL_W, waterHeight)

            for i = 1, 3 do
                if waveImgs[i] then
                    -- Calcular Y de la ola según nivel de agua
                    local waveBaseY = waterY + WAVE_Y_OFFSETS[i]
                    local ox = math.floor(waveOffsets[i])

                    -- Dibujar la ola repetida (seamless): tile izquierdo y derecho
                    -- para cubrir todo el BOWL_W sin importar el offset
                    waveImgs[i]:draw(BOWL_X + ox - WAVE_W, waveBaseY)
                    waveImgs[i]:draw(BOWL_X + ox,          waveBaseY)
                    waveImgs[i]:draw(BOWL_X + ox + WAVE_W, waveBaseY)
                end
            end

            gfx.clearClipRect()
        end
    end

    -- ── 3. Dibujar sprite del inodoro encima del agua ────────
    if toiletImg then
        toiletImg:draw(TOILET_X, TOILET_Y)
    else
        -- Fallback geométrico (si el sprite no cargó)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(TOILET_X + 15, TOILET_Y, 70, 40)
        gfx.drawRect(TOILET_X + 5,  TOILET_Y + 40, 90, 12)
        gfx.drawRect(TOILET_X + 10, TOILET_Y + 52, 80, 65)
        gfx.fillRect(TOILET_X + 25, TOILET_Y + 117, 50, 10)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(BOWL_X, BOWL_Y, BOWL_W, BOWL_H)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(BOWL_X, BOWL_Y, BOWL_W, BOWL_H)
    end

    -- ── 4. Dibujar partículas de splash ──────────────────────
    drawParticles(gfx)
end

-- Retorna los límites de la taza interior (usados por QTEManager)
function Toilet.getBowlBounds()
    return BOWL_X, BOWL_Y, BOWL_W, BOWL_H
end

-- Retorna la posición del sprite del inodoro (usada por QTEManager)
function Toilet.getToiletPos()
    return TOILET_X, TOILET_Y, TOILET_W, TOILET_H
end
