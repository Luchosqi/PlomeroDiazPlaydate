-- =============================================================
-- view/HUD.lua
-- Interfaz de usuario — Versión 3.0
-- Barra de agua: rectángulo negro con burbujas blancas
-- Nivel/Combo: panel blanco con borde negro para legibilidad
-- =============================================================

HUD = {}

-- ── Patrón de dithering para stamina media ────────────────────
local DITHER_PATTERN_50 = { 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55 }

-- ── Tabla de burbujas estáticas (posiciones relativas) ────────
-- Se generan una vez y se reusan para eficiencia
local BUBBLE_COLS   = 3   -- columnas de burbujas en la barra
local MAX_BUBBLES   = 18  -- máximo de puntos visibles

-- ── Variables de animación de burbujas ───────────────────────
local bubbleOffsets = {}  -- desplazamiento Y animado de cada burbuja
local bubblePhases  = {}  -- fase de oscilación
local bubbleXs      = {}  -- posición X fija (relativa al interior de la barra)

local function initBubbles()
    bubbleOffsets = {}
    bubblePhases  = {}
    bubbleXs      = {}
    -- Distribuir X fijas en columnas dentro de la barra (STA_W = 13, margen 2px)
    local innerW = Layout.STA_W - 4
    for i = 1, MAX_BUBBLES do
        -- Distribuir en BUBBLE_COLS columnas
        local col = ((i - 1) % BUBBLE_COLS)
        bubbleXs[i]      = 2 + math.floor((col / BUBBLE_COLS) * innerW)
        bubblePhases[i]  = (i * 1.37) % (2 * math.pi)  -- fase distinta para cada burbuja
        bubbleOffsets[i] = 0
    end
end

function HUD.init()
    initBubbles()
end

-- ── Dibujo principal ──────────────────────────────────────────
function HUD.draw(gameState, subState, level)
    if gameState ~= 2 then return end

    local gfx     = playdate.graphics
    local ms      = playdate.getCurrentTimeMilliseconds()
    local t       = ms / 1000.0
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

    -- ── Panel de Nivel y Combo (esquina superior derecha) ──────
    -- Panel blanco con borde negro para que el texto sea legible
    -- sobre cualquier fondo de muralla
    local infoX, infoY, infoW, infoH = 300, 20, 96, 30
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(infoX, infoY, infoW, infoH, 4)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(infoX, infoY, infoW, infoH, 4)
    gfx.drawRoundRect(infoX + 1, infoY + 1, infoW - 2, infoH - 2, 3)  -- borde doble sutil

    -- Combo / multiplicador
    local comboStr
    if combo >= 2 then
        comboStr = "x" .. combo .. " COMBO"
    else
        comboStr = "x1"
    end

    if combo >= 10 then
        -- Mega combo: fondo invertido (negro con texto blanco)
        if (math.floor(ms / 200) % 2) == 0 then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRoundRect(infoX + 1, infoY + 1, infoW - 2, infoH - 2, 3)
            gfx.setColor(gfx.kColorWhite)
        else
            gfx.setColor(gfx.kColorBlack)
        end
        gfx.drawTextAligned(comboStr, infoX + math.floor(infoW / 2), infoY + 14, kTextAlignment.center)
        gfx.setColor(gfx.kColorBlack)
    else
        gfx.setColor(gfx.kColorBlack)
        gfx.drawTextAligned(comboStr, infoX + math.floor(infoW / 2), infoY + 14, kTextAlignment.center)
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
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(sx + 1, fillY, sw - 2, fillH)
        elseif stamina >= 20 then
            gfx.setPattern(DITHER_PATTERN_50)
            gfx.fillRect(sx + 1, fillY, sw - 2, fillH)
            gfx.setColor(gfx.kColorBlack)
        else
            -- Crítico: parpadeo rápido
            if (math.floor(ms / 150) % 2) == 0 then
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRect(sx + 1, fillY, sw - 2, fillH)
            end
        end
    end

    -- Etiqueta "E"
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("E", sx + 2, sy + sh + 2)

    -- ── Barra de Agua con Burbujas (derecha) ──────────────────
    -- Barra más ancha: 20px de ancho
    local barW  = 20
    local barH  = Layout.DROP_SIZE * Layout.DROP_COUNT + Layout.DROP_GAP * (Layout.DROP_COUNT - 1)
    local barX  = 400 - barW - 2   -- pegada al borde derecho
    local barY  = Layout.DROP_Y0

    -- Fondo negro sólido
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(barX, barY, barW, barH)

    -- Borde blanco exterior
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(barX - 1, barY - 1, barW + 2, barH + 2)

    -- Nivel de agua: altura proporcional dentro de la barra
    local waterH = math.floor((water / 100) * barH)
    local waterY = barY + (barH - waterH)

    -- ── Burbujas blancas subiendo dentro de la zona de agua ──
    if waterH > 4 then
        local isPanic = water >= 80
        local innerBarX = barX + 2
        local innerBarW = barW - 4

        -- Clipping al interior de la zona de agua
        gfx.setClipRect(innerBarX, waterY + 2, innerBarW, waterH - 4)
        gfx.setColor(gfx.kColorWhite)

        -- Número de burbujas proporcional al nivel de agua
        local activeBubbles = math.max(3, math.floor((water / 100) * MAX_BUBBLES))

        for i = 1, activeBubbles do
            -- Movimiento: la burbuja sube suavemente y hace wrap
            local phase  = bubblePhases[i] or (i * 1.37)
            -- Y animada: se mueve de abajo hacia arriba
            local baseY  = waterY + waterH - 3
            local animY  = baseY - math.floor(((t * (0.8 + (i % 3) * 0.3) + phase) % 1.0) * waterH)
            -- X: columna fija + pequeño bamboleo horizontal
            local bx = innerBarX + (bubbleXs[i] or 2)
            local finalBx = bx + math.floor(math.sin(t * 2 + phase) * 2)

            -- Tamaño de burbuja: 1 o 2 px
            local sz = (i % 3 == 0) and 2 or 1
            if sz == 1 then
                gfx.drawPixel(finalBx, animY)
            else
                gfx.fillRect(finalBx, animY, 2, 2)
            end

            -- En pánico: doble de burbujas visibles (duplicar con offset)
            if isPanic then
                local bx2  = innerBarX + ((bubbleXs[i] or 2) + math.floor(innerBarW / 2)) % innerBarW
                local animY2 = baseY - math.floor(((t * 1.2 + phase + 0.5) % 1.0) * waterH)
                gfx.drawPixel(bx2, animY2)
            end
        end

        gfx.clearClipRect()
    end

    -- Separador entre zona de agua y zona vacía (línea blanca)
    if waterH > 0 and waterH < barH then
        gfx.setColor(gfx.kColorWhite)
        gfx.drawLine(barX, waterY, barX + barW - 1, waterY)
    end

    -- Etiqueta "A"
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("A", barX + 6, barY + barH + 2)

    -- ── Indicadores de sub-estado ─────────────────────────────
    if subState == 2 then
        local bx, by, bw, bh = 120, 184, 160, 22
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRoundRect(bx, by, bw, bh, 5)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRoundRect(bx + 2, by + 2, bw - 4, bh - 4, 3)
        gfx.drawTextAligned("♪ CALISTENIA ♪", 200, by + 4, kTextAlignment.center)

    elseif subState == 3 then
        if (math.floor(ms / 220) % 2) == 0 then
            local bx, by, bw, bh = 130, 184, 140, 22
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(bx, by, bw, bh)
            gfx.setColor(gfx.kColorWhite)
            gfx.drawRect(bx + 1, by + 1, bw - 2, bh - 2)
            gfx.drawTextAligned("⚠ PANICO ⚠", 200, by + 4, kTextAlignment.center)
        end
    end

    -- ── Flow State (combo ≥ 4) ───────────────────────────────
    if combo >= 4 and subState == 1 then
        local flowStr = "✦ FLOW x" .. combo
        if combo >= 10 then
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
            gfx.drawRoundRect(310, 52, 82, 16, 4)
        end
        gfx.setColor(gfx.kColorBlack)
        gfx.drawTextAligned(flowStr, 351, 54, kTextAlignment.center)
    end
end
