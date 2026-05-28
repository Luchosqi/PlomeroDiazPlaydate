-- =============================================================
-- model/ScoreManager.lua
-- Gestión de puntuación y monedas Díaz-Coins
-- =============================================================

ScoreManager = {}

local score          = 0
local coins          = 0
local levelStartTime = 0

-- Inicializar o reiniciar la puntuación
function ScoreManager.init()
    score          = 0
    coins          = 0
    levelStartTime = playdate.getCurrentTimeMilliseconds()
end

function ScoreManager.getScore() return score end
function ScoreManager.getCoins() return coins end

-- Añadir puntos por completar un QTE exitoso
-- baseValue   : penalización del obstáculo (usado como valor base)
-- comboNow    : combo activo al momento de completar
-- speedBonus  : multiplicador por velocidad de resolución (1.0 – 2.0)
function ScoreManager.addQTEScore(baseValue, comboNow, speedBonus)
    local multiplier = ComboSystem.getMultiplier()
    local points     = math.floor(baseValue * multiplier * speedBonus)
    score += points
end

-- Bonus al completar un nivel (drenar el agua a 0%)
-- level    : nivel recién completado
-- maxCombo : máximo combo alcanzado en ese nivel
function ScoreManager.addLevelBonus(level, maxCombo)
    local elapsed   = (playdate.getCurrentTimeMilliseconds() - levelStartTime) / 1000
    local coinsBase = (level * 10) + (maxCombo * 5)
    local timeBonus = math.max(0, 50 - elapsed) * 0.5
    local earned    = math.floor(coinsBase + timeBonus)

    coins  += earned
    score  += earned * 100

    -- Resetear temporizador para el siguiente nivel
    levelStartTime = playdate.getCurrentTimeMilliseconds()
end
