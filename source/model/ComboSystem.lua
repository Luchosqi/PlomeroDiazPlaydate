-- =============================================================
-- model/ComboSystem.lua
-- Sistema de racha (combo) y multiplicadores de puntuación
-- =============================================================

ComboSystem = {}

local combo    = 1
local maxCombo = 1

-- Inicializar o reiniciar el sistema de combo
function ComboSystem.init()
    combo    = 1
    maxCombo = 1
end

-- Retorna el combo actual
function ComboSystem.getCombo()
    return combo
end

-- Retorna el combo máximo alcanzado en esta partida
function ComboSystem.getMaxCombo()
    return maxCombo
end

-- Suma 1 al combo y actualiza el máximo
function ComboSystem.addCombo()
    combo += 1
    if combo > maxCombo then
        maxCombo = combo
    end
end

-- Reinicia el combo a 1 (al fallar un QTE o entrar en pánico)
function ComboSystem.resetCombo()
    combo = 1
end

-- Retorna el multiplicador de puntos según la racha actual
-- Tabla: 1 → x1 | 2–3 → x2 | 4–6 → x3 | 7–9 → x4 | 10+ → x5
function ComboSystem.getMultiplier()
    if combo >= 10 then return 5
    elseif combo >= 7 then return 4
    elseif combo >= 4 then return 3
    elseif combo >= 2 then return 2
    else                   return 1
    end
end

-- ¿Está activo el Estado de Flujo? (combo >= 4)
function ComboSystem.isInFlow()
    return combo >= 4
end
