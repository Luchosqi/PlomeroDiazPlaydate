-- =============================================================
-- Plomero Díaz - main.lua
-- Punto de entrada del juego para Playdate
-- =============================================================

import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/ui"

import "model/Layout"
import "model/ComboSystem"
import "model/ScoreManager"
import "model/Player"
import "model/Toilet"
import "model/QTEManager"
import "model/GameManager"
import "view/HUD"
local gfx <const> = playdate.graphics


math.randomseed(playdate.getSecondsSinceEpoch())

playdate.display.setRefreshRate(30)

GameManager.init()


function playdate.update()
    gfx.clear(gfx.kColorWhite)
    playdate.timer.updateTimers()
    GameManager.update()
end
