-- =============================================================
-- view/HUD.lua  — Versión 4.0
-- CAMBIOS v4.0:
--   [FIX]  Eliminado el "x1" suelto en la esquina superior derecha
--   [NEW]  Panel "Nivel N" con rect blanco + borde negro (legible sobre muralla)
--   [NEW]  Combo mostrado SEPARADO del nivel, debajo del panel de nivel
--   [FIX]  Barra de agua: burbujas animadas (sin cambios, ya funcionaba bien)
-- =============================================================

HUD = {}

-- ── Patrón de dithering para stamina media ────────────────────
local DITHER_PATTERN_50 = { 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55 }

-- ── Burbujas de la barra de agua ─────────────────────────────
local MAX_BUBBLES  = 18
local BUBBLE_COLS  = 3
local bubblePhases = {}
local bubbleXs     = {}

local function initBubbles()
    bubblePhases = {}
    bubbleXs     = {}
    local innerW = Layout.STA_W - 4
    for i = 1, MAX_BUBBLES do
        local col        = ((i - 1) % BUBBLE_COLS)
        bubbleXs[i]      = 2 + math.floor((col / BUBBLE_COLS) * innerW)
        bubblePhases[i]  = (i * 1.37) % (2 * math.pi)
    end
end

function HUD.init()
    initBubbles()
end

-- ─────────────────────────────────────────────────────────────
-- ── DIBUJO PRINCIPAL ─────────────────────────────────────────
-- ─────────────────────────────────────────────────────────────
function HUD.draw(gameState, subState, level)
    if gameState ~= 2 then return end   -- Solo durante gameplay

    local gfx     = playdate.graphics
    local ms      = playdate.getCurrentTimeMilliseconds()
    local t       = ms / 1000.0
    local stamina = Player.getStamina()
    local water   = Toilet.getWaterLevel()
    local combo   = ComboSystem.getCombo()

    -- ── Barra superior negra ──────────────────────────────────
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, 400, Layout.TOPBAR_H)
    gfx.setColor(gfx.kColorWhite)

    -- Score y coins en la barra superior
    gfx.drawText("SCORE:" .. ScoreManager.getScore(), 20, 2)
    gfx.drawText("COINS:" .. ScoreManager.getCoins(), 170, 2)

    -- ── [NEW] Panel "Nivel N" — esquina superior derecha ──────
    -- Rectángulo blanco sólido con borde negro fino.
    -- Reemplaza el "x1" suelto que no era legible sobre las murallas.
    local nivX, nivY, nivW, nivH = 316, 20, 80, 20

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(nivX, nivY, nivW, nivH)          -- fondo blanco sólido
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(nivX, nivY, nivW, nivH)          -- borde negro fino
    gfx.drawRect(nivX + 1, nivY + 1, nivW - 2, nivH - 2)  -- borde doble para "gordura"

    -- Texto "Nivel N" centrado dentro del panel
    gfx.setColor(gfx.kColorBlack)
    gfx.drawTextAligned("Nivel " .. level, nivX + math.floor(nivW / 2), nivY + 4, kTextAlignment.center)

    -- ── [NEW] Panel de Combo (justo debajo del panel de nivel) ─
    -- Solo se muestra si hay combo activo (≥ 2); así no aparece "x1" molesto.
    if combo >= 2 then
        local cmbX, cmbY, cmbW, cmbH = 316, 44, 80, 18
        local comboStr = "x" .. combo .. " COMBO"

        if combo >= 10 then
            -- Mega combo: fondo invertido parpadeante
            if (math.floor(ms / 200) % 2) == 0 then
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRect(cmbX, cmbY, cmbW, cmbH)
                gfx.setColor(gfx.kColorWhite)
            else
                gfx.setColor(gfx.kColorWhite)
                gfx.fillRect(cmbX, cmbY, cmbW, cmbH)
                gfx.setColor(gfx.kColorBlack)
                gfx.drawRect(cmbX, cmbY, cmbW, cmbH)
            end
        else
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(cmbX, cmbY, cmbW, cmbH)
            gfx.setColor(gfx.kColorBlack)
            gfx.drawRect(cmbX, cmbY, cmbW, cmbH)
        end
        gfx.setColor(gfx.kColorBlack)
        gfx.drawTextAligned(comboStr, cmbX + math.floor(cmbW / 2), cmbY + 3, kTextAlignment.center)
    end

    -- ── Barra de Stamina (lado izquierdo) ─────────────────────
    local sx  = Layout.STA_X
    local sy  = Layout.STA_Y
    local sw  = Layout.STA_W
    local sh  = Layout.STA_H

    local fillH = math.floor((stamina / 100) * sh)
    local fillY = sy + (sh - fillH)

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
            -- Crítico: parpadea
            if (math.floor(ms / 150) % 2) == 0 then
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRect(sx + 1, fillY, sw - 2, fillH)
            end
        end
    end

    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("E", sx + 2, sy + sh + 2)

    -- ── Barra de Agua con Burbujas (lado derecho) ─────────────
    local barW = 20
    local barH = Layout.DROP_SIZE * Layout.DROP_COUNT + Layout.DROP_GAP * (Layout.DROP_COUNT - 1)
    local barX = 400 - barW - 2
    local barY = Layout.DROP_Y0

    -- Fondo negro sólido
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(barX, barY, barW, barH)

    -- Borde blanco exterior
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(barX - 1, barY - 1, barW + 2, barH + 2)

    -- Altura de la zona de agua
    local waterH = math.floor((water / 100) * barH)
    local waterY = barY + (barH - waterH)

    -- Burbujas blancas subiendo dentro del agua
    if waterH > 4 then
        local isPanic   = water >= 80
        local innerBarX = barX + 2
        local innerBarW = barW - 4

        gfx.setClipRect(innerBarX, waterY + 2, innerBarW, waterH - 4)
        gfx.setColor(gfx.kColorWhite)

        local activeBubbles = math.max(3, math.floor((water / 100) * MAX_BUBBLES))
        for i = 1, activeBubbles do
            local phase   = bubblePhases[i] or (i * 1.37)
            local baseY   = waterY + waterH - 3
            local animY   = baseY - math.floor(((t * (0.8 + (i % 3) * 0.3) + phase) % 1.0) * waterH)
            local bx      = innerBarX + (bubbleXs[i] or 2)
            local finalBx = bx + math.floor(math.sin(t * 2 + phase) * 2)
            local sz      = (i % 3 == 0) and 2 or 1

            if sz == 1 then
                gfx.drawPixel(finalBx, animY)
            else
                gfx.fillRect(finalBx, animY, 2, 2)
            end

            if isPanic then
                local bx2   = innerBarX + ((bubbleXs[i] or 2) + math.floor(innerBarW / 2)) % innerBarW
                local animY2 = baseY - math.floor(((t * 1.2 + phase + 0.5) % 1.0) * waterH)
                gfx.drawPixel(bx2, animY2)
            end
        end
        gfx.clearClipRect()
    end

    -- Línea divisoria zona de agua / vacío
    if waterH > 0 and waterH < barH then
        gfx.setColor(gfx.kColorWhite)
        gfx.drawLine(barX, waterY, barX + barW - 1, waterY)
    end

    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("A", barX + 6, barY + barH + 2)

    -- ── Indicadores de sub-estado ─────────────────────────────
    if subState == 2 then
        -- Calistenia
        local bx, by, bw, bh = 120, 184, 160, 22
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRoundRect(bx, by, bw, bh, 5)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRoundRect(bx + 2, by + 2, bw - 4, bh - 4, 3)
        gfx.drawTextAligned("♪ CALISTENIA ♪", 200, by + 4, kTextAlignment.center)

    elseif subState == 3 then
        -- Pánico: banner parpadeante
        if (math.floor(ms / 220) % 2) == 0 then
            local bx, by, bw, bh = 130, 184, 140, 22
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(bx, by, bw, bh)
            gfx.setColor(gfx.kColorWhite)
            gfx.drawRect(bx + 1, by + 1, bw - 2, bh - 2)
            gfx.drawTextAligned("⚠ PANICO ⚠", 200, by + 4, kTextAlignment.center)
        end
    end

    -- ── Flow State (combo ≥ 4, subEstado normal) ─────────────
    if combo >= 4 and subState == 1 then
        local flowStr = "✦ FLOW x" .. combo
        -- Panel debajo del combo
        local fX, fY, fW, fH = 316, 66, 80, 16
        if combo >= 10 then
            if (math.floor(ms / 200) % 2) == 0 then
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRect(fX, fY, fW, fH)
                gfx.setColor(gfx.kColorWhite)
            else
                gfx.setColor(gfx.kColorWhite)
                gfx.fillRect(fX, fY, fW, fH)
                gfx.setColor(gfx.kColorBlack)
                gfx.drawRect(fX, fY, fW, fH)
            end
        else
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(fX, fY, fW, fH)
            gfx.setColor(gfx.kColorBlack)
            gfx.drawRect(fX, fY, fW, fH)
        end
        gfx.setColor(gfx.kColorBlack)
        gfx.drawTextAligned(flowStr, fX + math.floor(fW / 2), fY + 2, kTextAlignment.center)
    end
end
