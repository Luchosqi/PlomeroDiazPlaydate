-- =============================================================
-- model/Player.lua
-- Lógica del Profesor Díaz: stamina, crank y animaciones
-- =============================================================

Player = {}

-- ── Constantes ───────────────────────────────────────────────
local STAMINA_MAX          <const> = 100
local DRAIN_PER_ROTATION   <const> = 2.0   -- agua drenada por vuelta completa (ajustado para balance)
local CRANK_BLOCK_FRAMES   <const> = 60    -- bloqueo de 2 s al agotar stamina (30 fps)
local DEGREES_OVERSPEED    <const> = 20    -- grados/frame que activan penalización por velocidad excesiva

-- ── Layout: posición en pantalla ─────────────────────────────
-- Se lee desde Layout.lua en Player.init() para que sea centralizado
local POS_X = 22
local POS_Y = 118

-- ── Estado interno ───────────────────────────────────────────
local stamina       = STAMINA_MAX
local drainAmount   = 0          -- agua a drenar este frame (resultado del crank)
local crankBlocked  = false
local blockTimer    = 0
local playerState   = "idle"     -- "idle" | "work" | "calistenia" | "lose"

-- Animación de trabajo
local workFrame      = 1
local workFrameTimer = 0
local prevCrankAngle = 0

-- ── Imágenes (cargadas lazy) ──────────────────────────────────
local imgIdle       = nil
local imgCalistenia = nil
local imgLose       = nil
local imgWorkTable  = nil
local imagesLoaded  = false

local function loadImages()
    if imagesLoaded then return end
    imagesLoaded  = true
    imgIdle       = playdate.graphics.image.new("assets/images/diaz_idle")
    imgCalistenia = playdate.graphics.image.new("assets/images/diaz_calistenia")
    imgLose       = playdate.graphics.image.new("assets/images/diaz_lose")
    imgWorkTable  = playdate.graphics.imagetable.new("assets/images/diaz_work")
end

-- ── Placeholder visual cuando no hay sprite ───────────────────
local function drawPlaceholder(state)
    local gfx = playdate.graphics
    local x, y, w, h = POS_X, POS_Y, 80, 100
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(x, y, w, h)
    -- Cabeza
    gfx.drawRect(x + 25, y + 5, 30, 30)
    -- Cuerpo
    gfx.drawRect(x + 20, y + 35, 40, 40)
    -- Piernas
    gfx.drawRect(x + 20, y + 75, 15, 20)
    gfx.drawRect(x + 45, y + 75, 15, 20)
    -- Sopapo si está trabajando
    if state == "work" then
        gfx.drawLine(x + 65, y + 50, x + 90, y + 80)
        gfx.fillRect(x + 80, y + 75, 20, 5)
    end
end

-- ── API pública ───────────────────────────────────────────────

function Player.init()
    -- Leer posición desde el Layout global
    POS_X = Layout.PLAYER_X
    POS_Y = Layout.PLAYER_Y

    stamina       = STAMINA_MAX
    drainAmount   = 0
    crankBlocked  = false
    blockTimer    = 0
    playerState   = "idle"
    workFrame     = 1
    workFrameTimer= 0
    prevCrankAngle= playdate.getCrankPosition()
    loadImages()
end

function Player.getStamina()    return stamina    end
function Player.getDrainAmount() return drainAmount end
function Player.getState()      return playerState  end

function Player.addStamina(amount)
    stamina = math.min(STAMINA_MAX, stamina + amount)
end

-- Llamar cada frame durante CALISTENIA (Botón B mantenido)
function Player.updateCalistenia()
    drainAmount = 0
    playerState = "calistenia"
    -- Recuperar 3 puntos de stamina por frame (muy rápido pero jugador no puede bombear)
    stamina = math.min(STAMINA_MAX, stamina + 3)
end

-- Llamar cada frame durante RUNNING / PANIC
function Player.update(level)
    drainAmount = 0

    -- Bloqueo de crank por agotamiento
    if crankBlocked then
        blockTimer -= 1
        if blockTimer <= 0 then
            crankBlocked = false
        end
        playerState = "lose"
        return
    end

    -- Si la manivela está guardada, reposo
    if playdate.isCrankDocked() then
        playerState = "idle"
        return
    end

    -- Calcular rotación acumulada este frame (solo horaria = positiva)
    local currentAngle = playdate.getCrankPosition()
    local delta = currentAngle - prevCrankAngle
    if delta > 180  then delta -= 360 end   -- wrap-around de 360→0
    if delta < -180 then delta += 360 end
    prevCrankAngle = currentAngle

    if delta > 0 then
        -- Costo de stamina proporcional al nivel (progresivo)
        local staminaCost = (1.0 + level * 0.12) * (delta / 360)
        -- Penalización por giro excesivamente rápido
        if delta > DEGREES_OVERSPEED then
            staminaCost *= 1.5
        end

        if stamina > 0 then
            stamina     = math.max(0, stamina - staminaCost)
            drainAmount = (delta / 360) * DRAIN_PER_ROTATION
        else
            -- Stamina agotada: bloquear crank 2 segundos
            crankBlocked = true
            blockTimer   = CRANK_BLOCK_FRAMES
            stamina      = 0
        end

        playerState = "work"

        -- Avanzar fotograma de animación según giro acumulado
        workFrameTimer += delta
        if workFrameTimer >= 90 then
            workFrameTimer = 0
            workFrame      = (workFrame % 3) + 1
        end
    else
        -- Sin giro (o giro antihorario): reposo
        playerState = "idle"
    end
end

-- Dibujar el personaje en pantalla
function Player.draw()
    local gfx  = playdate.graphics
    local x, y = POS_X, POS_Y

    if playerState == "idle" then
        if imgIdle then
            imgIdle:draw(x, y)
        else
            drawPlaceholder("idle")
        end

    elseif playerState == "work" then
        if imgWorkTable then
            local frame = imgWorkTable:getImage(workFrame)
            if frame then frame:draw(x, y) end
        else
            drawPlaceholder("work")
        end

    elseif playerState == "calistenia" then
        if imgCalistenia then
            imgCalistenia:draw(x, y)
        else
            drawPlaceholder("idle")
        end

    elseif playerState == "lose" then
        if imgLose then
            imgLose:draw(x, y)
        else
            drawPlaceholder("idle")
        end
    end
end
