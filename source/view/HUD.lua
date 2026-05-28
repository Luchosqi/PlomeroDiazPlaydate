-- =============================================================
-- view/HUD.lua
-- Interfaz de usuario — Versión 2.0
-- Gotas de agua apiladas, stamina con setPattern eficiente,
-- sub-estado con estilos mejorados
-- =============================================================

HUD = {}

-- ── Imágenes ─────────────────────────────────────────────────
local dropImg    = nil
local imgsLoaded = false

local function loadImages()
    if imgsLoaded then return end
    imgsLoaded = true
    dropImg = playdate.graphics.image.new("assets/images/ui_water_drop")
end

-- ── Patrón de dithering para stamina media ────────────────────
-- Bayer 2×2 50% (checkerboard). Se usa como setPattern para evitar
-- el costoso loop de píxeles frame a frame.
-- Playdate acepta una tabla de 8 bytes (8 filas de 8 bits = 8×8 px tile)
local DITHER_PATTERN_50 = { 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55 }

function HUD.init()
    loadImages()
end

-- ── Dibujo principal ──────────────────────────────────────────
function HUD.draw(gameState, subState, level)
    if gameState ~= 2 then return end

    local gfx     = playdate.graphics
    local ms      = playdate.getCurrentTimeMilliseconds()
    local stamina = Player.getStamina()
    local water   = Toilet.getWaterLevel()
    local combo   = ComboSystem.getCombo()

    -- ── Barra negra superior ──────────────────────────────────
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, 400, Layout.TOPBAR_H)
    gfx.setColor(gfx.kColorWhite)

    -- Nivel
    gfx.drawText("NVL:" .. level, 4, 2)

    -- Score
    gfx.drawText("SCORE:" .. ScoreManager.getScore(), 55, 2)

    -- Coins
    gfx.drawText("COINS:" .. ScoreManager.getCoins(), 195, 2)

    -- Combo (con animación si es alto)
    if combo >= 2 then
        local comboStr = "x" .. combo .. " COMBO"
        if combo >= 10 then
            -- Mega combo: parpadeo invertido
            if (math.floor(ms / 200) % 2) == 0 then
                gfx.setColor(gfx.kColorWhite)
                gfx.fillRect(305, 1, 90, 16)
                gfx.setColor(gfx.kColorBlack)
            else
                gfx.setColor(gfx.kColorWhite)
            end
            gfx.drawTextAligned(comboStr, 350, 2, kTextAlignment.center)
            gfx.setColor(gfx.kColorWhite)
        else
            gfx.drawTextAligned("x" .. combo .. " COMBO", 350, 2, kTextAlignment.center)
        end
    else
        gfx.drawText("x1", 355, 2)
    end

    -- ── Barra de Stamina (izquierda) ──────────────────────────
    local sx   = Layout.STA_X
    local sy   = Layout.STA_Y
    local sw   = Layout.STA_W
    local sh   = Layout.STA_H

    local fillH = math.floor((stamina / 100) * sh)
    local fillY = sy + (sh - fillH)

    -- Fondo blanco + borde
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(sx, sy, sw, sh)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(sx, sy, sw, sh)

    if fillH > 0 then
        if stamina >= 40 then
            -- Sólido negro
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(sx + 1, fillY, sw - 2, fillH)
        elseif stamina >= 20 then
            -- Dithering eficiente con setPattern
            gfx.setPattern(DITHER_PATTERN_50)
            gfx.fillRect(sx + 1, fillY, sw - 2, fillH)
            gfx.setColor(gfx.kColorBlack)  -- resetear color
        else
            -- Crítico: parpadeo rápido
            if (math.floor(ms / 150) % 2) == 0 then
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRect(sx + 1, fillY, sw - 2, fillH)
            end
        end
    end

    -- Etiqueta "E" (Energía)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("E", sx + 2, sy + sh + 2)

    -- ── Indicador de Agua: Gotas apiladas (derecha) ───────────
    local dropX      = Layout.DROP_X
    local dropY0     = Layout.DROP_Y0
    local dropSize   = Layout.DROP_SIZE
    local dropGap    = Layout.DROP_GAP
    local dropCount  = Layout.DROP_COUNT

    -- Cuántas gotas mostrar (0 a 10)
    local activeDrops = math.floor((water / 100) * dropCount)
    local isPanic     = water >= 80

    for i = 1, dropCount do
        -- Las gotas se apilan de abajo hacia arriba
        -- i=1 es la gota más baja (primera en llenarse)
        local gy = dropY0 + (dropCount - i) * (dropSize + dropGap)

        if i <= activeDrops then
            -- Gota activa (llena)
            if isPanic and (math.floor(ms / 150) % 2) == 0 then
                -- En pánico: gotas parpadean (dibujar solo contorno)
                gfx.setColor(gfx.kColorBlack)
                gfx.drawRect(dropX, gy, dropSize, dropSize)
            else
                if dropImg then
                    dropImg:draw(dropX, gy)
                else
                    -- Fallback: cuadrado relleno
                    gfx.setColor(gfx.kColorBlack)
                    gfx.fillRect(dropX, gy, dropSize, dropSize)
                end
            end
        else
            -- Gota vacía: solo contorno punteado (slot vacío)
            gfx.setColor(gfx.kColorBlack)
            gfx.drawRect(dropX, gy, dropSize, dropSize)
        end
    end

    -- Etiqueta "A" (Agua)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("A", dropX + 1, dropY0 + dropCount * (dropSize + dropGap) + 2)

    -- ── Indicadores de sub-estado ─────────────────────────────
    if subState == 2 then
        -- Calistenia: banner estilizado con borde doble
        local bx, by, bw, bh = 120, 184, 160, 22
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRoundRect(bx, by, bw, bh, 5)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRoundRect(bx + 2, by + 2, bw - 4, bh - 4, 3)
        gfx.drawTextAligned("♪ CALISTENIA ♪", 200, by + 4, kTextAlignment.center)

    elseif subState == 3 then
        -- Pánico: banner rojo parpadeante
        if (math.floor(ms / 220) % 2) == 0 then
            local bx, by, bw, bh = 130, 184, 140, 22
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(bx, by, bw, bh)
            gfx.setColor(gfx.kColorWhite)
            -- Borde de advertencia (doble línea)
            gfx.drawRect(bx + 1, by + 1, bw - 2, bh - 2)
            gfx.drawTextAligned("⚠ PANICO ⚠", 200, by + 4, kTextAlignment.center)
        end
    end

    -- ── Indicador de Flow State (combo ≥ 4) ──────────────────
    if combo >= 4 and subState == 1 then
        -- Mostrar estrella/badge de flow en esquina superior derecha de la zona de juego
        local flowStr = "✦ FLOW x" .. combo
        if combo >= 10 then
            -- Parpadeo de color alternado para combo extremo
            if (math.floor(ms / 200) % 2) == 0 then
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRoundRect(310, 20, 82, 16, 4)
                gfx.setColor(gfx.kColorWhite)
            else
                gfx.setColor(gfx.kColorWhite)
                gfx.fillRoundRect(310, 20, 82, 16, 4)
                gfx.setColor(gfx.kColorBlack)
                gfx.drawRoundRect(310, 20, 82, 16, 4)
            end
        else
            gfx.setColor(gfx.kColorBlack)
            gfx.drawRoundRect(310, 20, 82, 16, 4)
        end
        gfx.setColor(gfx.kColorBlack)
        gfx.drawTextAligned(flowStr, 351, 22, kTextAlignment.center)
    end
end
