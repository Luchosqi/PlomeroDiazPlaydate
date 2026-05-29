-- =============================================================
-- model/Layout.lua
-- Coordenadas globales centralizadas de la pantalla (400×240)
-- Todos los módulos deben usar estas constantes para posicionar
-- sus elementos visuales. Editar aquí para reajustar todo el juego.
-- =============================================================

Layout = {}

-- ── Fondo ─────────────────────────────────────────────────────
Layout.BG_X = 0
Layout.BG_Y = 0

-- ── Jugador (Profesor Díaz) ─────────────────────────────────
-- Sprites ahora son 120×150 px (1.5×), posición ajustada
Layout.PLAYER_X = 30
Layout.PLAYER_Y = 75

-- ── Inodoro ───────────────────────────────────────────────────
-- Centro-derecha de la pantalla, alineado con el bg_bathroom.png
Layout.TOILET_X = 225
Layout.TOILET_Y = 58
Layout.TOILET_W = 100
Layout.TOILET_H = 145

-- Bowl interior (zona donde se dibuja el agua y los obstáculos)
-- Relativo al sprite del inodoro
Layout.BOWL_X = Layout.TOILET_X + 12
Layout.BOWL_Y = Layout.TOILET_Y + 70
Layout.BOWL_W = 76
Layout.BOWL_H = 56

-- Centro exacto de la taza (para centrar obstáculos)
Layout.BOWL_CENTER_X = Layout.BOWL_X + math.floor(Layout.BOWL_W / 2)
Layout.BOWL_CENTER_Y = Layout.BOWL_Y + math.floor(Layout.BOWL_H / 2)

-- ── HUD — Barra de Stamina (izquierda) ───────────────────────
Layout.STA_X = 3
Layout.STA_Y = 22
Layout.STA_W = 13
Layout.STA_H = 170

-- ── HUD — Indicador de Agua (derecha) ────────────────────────
-- Columna de gotas (16×16 c/u, 10 gotas, separadas 1px)
-- Posición X: borde derecho de pantalla con margen
Layout.DROP_X    = 381   -- X de las gotas (borde der. de pantalla - 16 - 3)
Layout.DROP_Y0   = 22    -- Y de la gota más alta (gota 10 = agua llena)
Layout.DROP_SIZE = 16    -- tamaño de cada gota
Layout.DROP_GAP  = 2     -- espacio entre gotas
Layout.DROP_COUNT= 10    -- cuántas gotas en total

-- ── Panel QTE (franja inferior) ──────────────────────────────
Layout.QTE_PANEL_X = 30
Layout.QTE_PANEL_Y = 196    -- Y superior del globo/panel QTE
Layout.QTE_PANEL_W = 340
Layout.QTE_PANEL_H = 40
Layout.QTE_TIMER_Y = 194    -- Y de la barra de tiempo (encima del panel)
Layout.QTE_BUTTONS_Y = 207  -- Y donde se dibujan los iconos de botón

-- ── Barra superior de info ────────────────────────────────────
Layout.TOPBAR_H = 18        -- altura de la barra negra superior
