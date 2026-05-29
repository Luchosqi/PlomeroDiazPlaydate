-- =============================================================
-- view/HUD.lua  — Versión 5.0
-- CAMBIOS v5.0:
--   [NEW] Tipografía Nontendo Bold aplicada en el panel "Nivel N"
--         y en el indicador de combo/flow.
--   [FIX] Fuente restaurada a systemFont después de cada texto HUD
--         para no "contaminar" el estado de fuente global del juego.
--   Sin cambios en la lógica de barras (stamina + agua con burbujas).
-- =============================================================

HUD = {}

-- ── Patrón de dithering para stamina media ────────────────────
local DITHER_PATTERN_50 = { 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55 }

-- ── Burbujas de la barra de agua ─────────────────────────────
local MAX_BUBBLES  = 18
local BUBBLE_COLS  = 3
local bubblePhases = {}
local bubbleXs     = {}

-- [NEW v5.0] Referencias a fuentes (se obtienen en init para no buscar cada frame)
local boldFont   = nil
local systemFont = nil

local function initBubbles()
    bubblePhases = {}
    bubbleXs     = {}
    local innerW = Layout.STA_W - 4
    for i = 1, MAX_BUBBLES do
        local col       = ((i - 1) % BUBBLE_COLS)
        bubbleXs[i]     = 2 + math.floor((col / BUBBLE_COLS) * innerW)
        bubblePhases[i] = (i * 1.37) % (2 * math.pi)
    end
end

function HUD.init()
    initBubbles()
    -- [NEW v5.0] Cargar referencias de fuentes en init
    boldFont   = playdate.graphics.font.new("assets/font/nontendo-bold/Nontendo-Bold")
    systemFont = playdate.graphics.getSystemFont()
end

-- ── Helpers de tipografía locales ─────────────────────────────
local function useBold()
    if boldFont then playdate.graphics.setFont(boldFont) end
end
local function useSys()
    if systemFont then playdate.graphics.setFont(systemFont) end
end

-- ─────────────────────────────────────────────────────────────
-- ── DIBUJO PRINCIPAL ─────────────────────────────────────────
-- ─────────────────────────────────────────────────────────────
function HUD.draw(gameState, subState, level)
    if gameState ~= 2 then return end   -- Solo durante gameplay

    local gfx    = playdate.graphics
    local ms     = playdate.getCurrentTimeMilliseconds()
    local t      = ms / 1000.0
    local stamina = Player.getStamina()
    local water   = Toilet.getWaterLevel()
    local combo   = ComboSystem.getCombo()

    -- ── Barra superior negra (score / coins) ──────────────────
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, 400, Layout.TOPBAR_H)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawText("SCORE:" .. ScoreManager.getScore(), 20, 2)
    gfx.drawText("COINS:" .. ScoreManager.getCoins(), 170, 2)

    -- ── [NEW v5.0] Panel "Nivel N" — Nontendo Bold + rect blanco ──
    -- Rectángulo blanco sólido con borde negro doble para legibilidad
    -- sobre cualquier muralla o fondo dithered.
    local nivX, nivY, nivW, nivH = 314, 20, 84, 20

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(nivX, nivY, nivW, nivH)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(nivX, nivY, nivW, nivH)
    gfx.drawRect(nivX + 1, nivY + 1, nivW - 2, nivH - 2)   -- borde doble

    -- Texto "Nivel N" en Nontendo Bold
    useBold()
    gfx.setColor(gfx.kColorBlack)
    gfx.drawTextAligned("Nivel " .. level, nivX + math.floor(nivW / 2), nivY + 4, kTextAlignment.center)
    useSys()

    -- ── Panel de Combo (solo si combo ≥ 2) ────────────────────
    if combo >= 2 then
        local cmbX, cmbY, cmbW, cmbH = 314, 44, 84, 18
        local comboStr = "x" .. combo

        if combo >= 10 then
            -- Mega combo: inversión de colores parpadeante
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

        -- [NEW v5.0] Combo en Nontendo Bold
        useBold()
        gfx.setColor(gfx.kColorBlack)
        gfx.drawTextAligned(comboStr .. " COMBO", cmbX + math.floor(cmbW / 2), cmbY + 3, kTextAlignment.center)
        useSys()
    end

    -- ── Barra de Stamina (lado izquierdo) ─────────────────────
    local sx = Layout.STA_X
    local sy = Layout.STA_Y
    local sw = Layout.STA_W
    local sh = Layout.STA_H

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

    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(barX, barY, barW, barH)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(barX - 1, barY - 1, barW + 2, barH + 2)

    local waterH = math.floor((water / 100) * barH)
    local waterY = barY + (barH - waterH)

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
                local bx2    = innerBarX + ((bubbleXs[i] or 2) + math.floor(innerBarW / 2)) % innerBarW
                local animY2 = baseY - math.floor(((t * 1.2 + phase + 0.5) % 1.0) * waterH)
                gfx.drawPixel(bx2, animY2)
            end
        end
        gfx.clearClipRect()
    end

    if waterH > 0 and waterH < barH then
        gfx.setColor(gfx.kColorWhite)
        gfx.drawLine(barX, waterY, barX + barW - 1, waterY)
    end

    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("A", barX + 6, barY + barH + 2)

    -- ── Indicadores de sub-estado ─────────────────────────────
    if subState == 2 then
        local bx, by, bw, bh = 120, 184, 160, 22
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRoundRect(bx, by, bw, bh, 5)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRoundRect(bx + 2, by + 2, bw - 4, bh - 4, 3)
        -- [NEW v5.0] "Calistenia" en Nontendo Bold
        useBold()
        gfx.drawTextAligned("CALISTENIA", 200, by + 4, kTextAlignment.center)
        useSys()

    elseif subState == 3 then
        if (math.floor(ms / 220) % 2) == 0 then
            local bx, by, bw, bh = 120, 184, 160, 22
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(bx, by, bw, bh)
            gfx.setColor(gfx.kColorWhite)
            gfx.drawRect(bx + 1, by + 1, bw - 2, bh - 2)
            -- [NEW v5.0] "PANICO!" en Nontendo Bold
            useBold()
            gfx.drawTextAligned("PANICO!", 200, by + 4, kTextAlignment.center)
            useSys()
        end
    end

    -- ── Flow State (combo ≥ 4, sub-estado normal) ─────────────
    if combo >= 4 and subState == 1 then
        local flowStr = "FLOW x" .. combo
        local fX, fY, fW, fH = 314, 66, 84, 16

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

        -- [NEW v5.0] Flow en Nontendo Bold
        useBold()
        gfx.setColor(gfx.kColorBlack)
        gfx.drawTextAligned(flowStr, fX + math.floor(fW / 2), fY + 2, kTextAlignment.center)
        useSys()
    end
end
