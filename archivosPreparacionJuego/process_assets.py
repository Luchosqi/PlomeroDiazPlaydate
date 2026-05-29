#!/usr/bin/env python3
"""
process_assets.py  —  Versión 4.0
Convierte imágenes generadas por IA al formato 1-bit compatible con Playdate.

═══════════════════════════════════════════════════════════════════════════════
CAMBIOS v4.0
───────────────────────────────────────────────────────────────────────────────
[NEW] add_outline(): aplica un "contorno grueso" blanco alrededor del personaje
      para que resalte siempre sobre el fondo dithered. Thickness = 3 px.

[NEW] 3 fondos DISTINTOS (bg_bathroom_1/2/3.png) con instrucciones de diseño
      diferenciadas en los comentarios.

[NEW] Obstáculos más grandes: de 28×28 → 36×36 px.
      El círculo blanco de fondo se dibuja en Lua (no en Python).

[FIX] Los sprites del personaje se exportan en RGBA (transparencia real)
      y además se les aplica el outline blanco de 3 px.

[FIX] Inodoro también con outline para que resalte del fondo.
═══════════════════════════════════════════════════════════════════════════════

INSTRUCCIONES DE GENERACIÓN DE IMÁGENES (para la IA generadora)
───────────────────────────────────────────────────────────────────────────────

1. PERSONAJE "DIAZ" (diaz_idle, diaz_work_1/2/3, diaz_calistenia, diaz_lose)
   Prompt base:
   "1-bit pixel art, 120×150 pixels, stark black and white, NO grey.
    Slim young professor, white button-up shirt with rolled sleeves, dark jeans,
    short dark hair, red plunger tool. THICK WHITE OUTLINE (3 px) surrounding the
    entire character, so he stands out against any dithered background.
    Transparent background."
   Notas: el outline se puede agregar en Python con add_outline().

2. FONDOS DISTINTOS (un prompt por fondo):

   bg_bathroom_1.png — PARED DE LADRILLOS (nivel 1, 4, 7...)
   "400×240 pixel art, 1-bit black and white dithered texture.
    Old university bathroom brick wall, horizontal brick pattern with mortar lines.
    Subtle crack details. Dithered grey tones to simulate depth. No color."

   bg_bathroom_2.png — AZULEJOS UNIVERSITARIOS (nivel 2, 5, 8...)
   "400×240 pixel art, 1-bit black and white dithered texture.
    Classic square bathroom tiles 32×32 px, visible grout lines.
    Some tiles have university graffiti or water stains. Checkerboard-like pattern.
    Dithered grey to simulate dirty porcelain. No color."

   bg_bathroom_3.png — PARED CON GRAFITIS (nivel 3, 6, 9...)
   "400×240 pixel art, 1-bit black and white dithered texture.
    Rough concrete university bathroom wall covered with marker and spray-paint
    graffiti: equations, doodles, text bubbles. Heavy cross-hatching for the
    dark areas. Dense dithering. No color."

3. OBSTÁCULOS (obs_normal, obs_pelo, obs_banana, obs_car_red)
   Ahora son 36×36 px. El círculo blanco de fondo se dibuja en Lua.
   Prompt base:
   "1-bit pixel art icon, 36×36 pixels, high contrast black on transparent.
    NO square background (the Lua code adds a white circle).
    <descripción del obstáculo específico>. Bold black outlines."

   obs_normal  = "a cartoonish brown poop emoji shape"
   obs_pelo    = "a tangle of long hair strands"
   obs_banana  = "a curved banana shape"
   obs_car_red = "a small red car from the side (1-bit, all black)"

4. INODORO (toilet.png)
   "1-bit pixel art toilet, side view, 110×145 px, bold black outlines,
    3-pixel WHITE OUTLINE surrounding the entire toilet shape so it stands
    out against dithered backgrounds. Transparent background."

═══════════════════════════════════════════════════════════════════════════════

Uso:
    cd PlomeroDiaz/
    python3 archivosPreparacionJuego/process_assets.py

Requisitos:
    pip install Pillow
"""

import os
import glob
from PIL import Image, ImageFilter

# ── Rutas ────────────────────────────────────────────────────────────────────
ARTIFACT_DIR = "/home/luchosqi/.gemini/antigravity/brain/bf7b4f31-1cdb-4669-ad27-092621339f70"
GAME_ASSETS  = "/home/luchosqi/Documentos/Universidad/semestres/Semestre 5/PRACTICA 1/PlomeroDiaz/source/assets/images"

# ── Tabla de sprites ──────────────────────────────────────────────────────────
# Columnas: (glob_pattern, target_name, width, height, use_dither, threshold, transparent_bg, outline_px)
#   transparent_bg=True  → exporta RGBA (canal alfa)
#   transparent_bg=False → exporta L 8-bit opaco
#   outline_px > 0       → agrega un outline BLANCO de N píxeles alrededor de los trazos negros
#                          (solo tiene efecto cuando transparent_bg=True)
SPRITES = [
    # ── Personaje Díaz — RGBA transparente + outline blanco 3 px ─────────────
    ("diaz_idle_*.png",        "diaz_idle.png",           120, 150, True,  128, True,  3),
    ("diaz_work_1_*.png",      "diaz_work-table-1.png",   120, 150, True,  128, True,  3),
    ("diaz_work_2_*.png",      "diaz_work-table-2.png",   120, 150, True,  128, True,  3),
    ("diaz_work_3_*.png",      "diaz_work-table-3.png",   120, 150, True,  128, True,  3),
    ("diaz_calistenia_*.png",  "diaz_calistenia.png",     120, 150, True,  128, True,  3),
    ("diaz_lose_*.png",        "diaz_lose.png",           120, 150, True,  128, True,  3),

    # ── Inodoro — RGBA transparente + outline blanco 2 px ────────────────────
    ("toilet_*.png",           "toilet.png",              110, 145, True,  128, True,  2),

    # ── Fondos DISTINTOS × 3 (opacos, llenan toda la pantalla) ───────────────
    # IMPORTANTE: si tienes 3 imágenes distintas en ARTIFACT_DIR,
    # renómbralas: bg_bathroom_1_*.png, bg_bathroom_2_*.png, bg_bathroom_3_*.png
    # Si solo tienes una (bg_bathroom_*.png), los 3 fondos se generan desde la misma
    # con umbrales distintos como diferenciación temporal hasta tener los 3 diseños.
    ("bg_bathroom_1_*.png",    "bg_bathroom_1.png",       400, 240, True,  130, False, 0),
    ("bg_bathroom_2_*.png",    "bg_bathroom_2.png",       400, 240, True,  145, False, 0),
    ("bg_bathroom_3_*.png",    "bg_bathroom_3.png",       400, 240, True,  115, False, 0),
    # Genérico (fallback por si algún módulo lo llama)
    ("bg_bathroom_*.png",      "bg_bathroom.png",         400, 240, True,  130, False, 0),

    # ── Obstáculos — opacos, 36×36 px (más grandes que antes) ───────────────
    ("obs_normal_*.png",       "obs_normal.png",           36,  36, False, 110, False, 0),
    ("obs_pelo_*.png",         "obs_pelo.png",             36,  36, False, 100, False, 0),
    ("obs_banana_*.png",       "obs_banana.png",           36,  36, False, 110, False, 0),
    ("obs_car_red_*.png",      "obs_car_red.png",          36,  36, False, 110, False, 0),

    # ── Moneda ────────────────────────────────────────────────────────────────
    ("coin_*.png",             "coin.png",                 10,  10, False, 100, False, 0),

    # ── Flush (animación nivel completado) ────────────────────────────────────
    ("flush_1_*.png",          "flush-table-1.png",        90,  90, True,  128, False, 0),
    ("flush_1_*.png",          "flush-table-2.png",        90,  90, True,  128, False, 0),
    ("flush_1_*.png",          "flush-table-3.png",        90,  90, True,  128, False, 0),
    ("flush_1_*.png",          "flush-table-4.png",        90,  90, True,  128, False, 0),
    ("flush_1_*.png",          "flush-table-5.png",        90,  90, True,  128, False, 0),

    # ── HUD ───────────────────────────────────────────────────────────────────
    ("ui_water_drop_*.png",    "ui_water_drop.png",        16,  16, False, 100, False, 0),
]

# Rotaciones para la animación de flush
FLUSH_ROTATIONS = {
    "flush-table-1.png": 0,
    "flush-table-2.png": 72,
    "flush-table-3.png": 144,
    "flush-table-4.png": 216,
    "flush-table-5.png": 288,
}

# ── Recortes compuestos (spritesheet → sprites individuales) ─────────────────
COMPOSITE_CROPS = [
    # Olas ukiyo-e desde wave_set_*.png (3 franjas horizontales)
    ("wave_set_*.png", [
        ("wave_1.png",   (0,   0, 1024, 340),  96, 32, False, 128, False, 0),
        ("wave_2.png",   (0, 340, 1024, 680),  96, 32, False, 128, False, 0),
        ("wave_3.png",   (0, 680, 1024, 1024), 96, 32, False, 128, False, 0),
    ]),
    # Botones UI desde ui_arrows_set_*.png
    ("ui_arrows_set_*.png", [
        ("ui_arrow_up.png",    (0,   400, 205, 700), 24, 24, False, 100, False, 0),
        ("ui_arrow_down.png",  (205, 400, 410, 700), 24, 24, False, 100, False, 0),
        ("ui_arrow_left.png",  (410, 400, 615, 700), 24, 24, False, 100, False, 0),
        ("ui_arrow_right.png", (615, 400, 820, 700), 24, 24, False, 100, False, 0),
        ("ui_button_a.png",    (820, 400, 1024,700), 24, 24, False, 100, False, 0),
    ]),
]

# ── Funciones ─────────────────────────────────────────────────────────────────

def find_source(pattern):
    """Encuentra el archivo más reciente que coincida con el patrón glob."""
    matches = sorted(glob.glob(os.path.join(ARTIFACT_DIR, pattern)))
    return matches[-1] if matches else None

def prepare_image_rgb(img):
    """Normaliza a RGB con fondo blanco."""
    if img.mode in ('RGBA', 'LA'):
        bg = Image.new("RGBA", img.size, (255, 255, 255, 255))
        bg.paste(img, mask=img.split()[-1])
        return bg.convert('RGB')
    elif img.mode == 'P':
        img = img.convert('RGBA')
        bg  = Image.new("RGBA", img.size, (255, 255, 255, 255))
        bg.paste(img, mask=img.split()[-1])
        return bg.convert('RGB')
    elif img.mode != 'RGB':
        return img.convert('RGB')
    return img

def to_1bit_opaque(img_rgb, width, height, use_dither, threshold, rotation=0):
    """Convierte a 1-bit modo L (opaco, compatible con Playdate imagetables)."""
    if rotation != 0:
        img_rgb = img_rgb.rotate(rotation, expand=False, fillcolor=(255, 255, 255))
    img_rgb = img_rgb.resize((width, height), Image.Resampling.LANCZOS)
    gray    = img_rgb.convert('L')
    if use_dither:
        bw = gray.convert('1')
    else:
        bw = gray.point(lambda x: 255 if x > threshold else 0, '1')
    return bw.convert('L')

def to_rgba_transparent(img_src, width, height, use_dither, threshold, rotation=0):
    """
    Convierte a RGBA: trazos negros opacos, fondo blanco transparente.
    Playdate usa el canal alfa del PNG como máscara de dibujo.
    """
    if rotation != 0:
        img_src = img_src.rotate(rotation, expand=False, fillcolor=(255, 255, 255))
    img_src = img_src.resize((width, height), Image.Resampling.LANCZOS)
    gray    = img_src.convert('L')

    if use_dither:
        bw = gray.convert('1').convert('L')
    else:
        bw = gray.point(lambda x: 0 if x <= threshold else 255, 'L')

    # Construir canal alfa: negro=255 (opaco), blanco=0 (transparente)
    rgba       = Image.new('RGBA', bw.size, (255, 255, 255, 0))
    pix_bw     = bw.load()
    pix_rgba   = rgba.load()
    w, h = bw.size
    for y in range(h):
        for x in range(w):
            if pix_bw[x, y] < 128:
                pix_rgba[x, y] = (0, 0, 0, 255)   # trazo negro opaco
            else:
                pix_rgba[x, y] = (255, 255, 255, 0)  # fondo transparente
    return rgba

def add_outline(rgba_img, thickness=3):
    """
    [NEW v4.0] Agrega un outline BLANCO de N píxeles alrededor de los trazos negros
    en una imagen RGBA. Técnica: dilatar el canal alfa, luego colorear de blanco
    los píxeles nuevos (los que no eran parte del sprite original).

    Algoritmo:
      1. Extraer canal alfa original (255 = trazo).
      2. Dilatar ese canal N veces usando MaxFilter.
      3. Los píxeles que pasaron de 0→255 en la dilatación son el outline.
      4. Pintar esos píxeles de blanco opaco.
      5. Dejar los píxeles originales negros intactos encima.
    """
    # Canal alfa original
    alpha_orig = rgba_img.split()[3]

    # Dilatar el canal alfa para expandir el outline
    alpha_dilated = alpha_orig
    for _ in range(thickness):
        alpha_dilated = alpha_dilated.filter(ImageFilter.MaxFilter(3))

    # Pixels del outline = dilatados pero NO originales
    orig_pixels     = alpha_orig.load()
    dilated_pixels  = alpha_dilated.load()
    result          = rgba_img.copy()
    result_pixels   = result.load()
    w, h = rgba_img.size

    for y in range(h):
        for x in range(w):
            if dilated_pixels[x, y] > 128 and orig_pixels[x, y] < 128:
                # Outline: blanco opaco
                result_pixels[x, y] = (255, 255, 255, 255)

    return result

def save_result(result_img, target_name):
    """Guarda la imagen en el directorio de assets del juego."""
    target_path = os.path.join(GAME_ASSETS, target_name)
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    result_img.save(target_path, 'PNG')

def process_sprite(pattern, target_name, width, height, use_dither, threshold,
                   transparent_bg=False, outline_px=0):
    """Procesa un sprite simple (sin recorte)."""
    source_path = find_source(pattern)
    if source_path is None:
        print(f"  ⚠️  No encontrado: {pattern}")
        return False
    try:
        img_raw  = Image.open(source_path)
        rotation = FLUSH_ROTATIONS.get(target_name, 0)

        if transparent_bg:
            img_rgb = img_raw.convert('RGB')
            result  = to_rgba_transparent(img_rgb, width, height, use_dither, threshold, rotation)
            # [NEW] Aplicar outline blanco si se pide
            if outline_px > 0:
                result = add_outline(result, thickness=outline_px)
            label = f"RGBA {width}×{height}" + (f" + outline {outline_px}px" if outline_px > 0 else "")
        else:
            img_rgb = prepare_image_rgb(img_raw)
            result  = to_1bit_opaque(img_rgb, width, height, use_dither, threshold, rotation)
            label   = f"L {width}×{height}"

        save_result(result, target_name)
        print(f"  ✅ {os.path.basename(source_path):42s} → {target_name} ({label})")
        return True
    except Exception as e:
        print(f"  ❌ Error en {pattern}: {e}")
        return False

def process_composite(pattern, crops):
    """Recorta múltiples sprites desde una imagen compuesta (spritesheet)."""
    source_path = find_source(pattern)
    if source_path is None:
        print(f"  ⚠️  Compuesto no encontrado: {pattern}")
        return 0, len(crops)

    try:
        img_raw = Image.open(source_path)
    except Exception as e:
        print(f"  ❌ No se pudo abrir {pattern}: {e}")
        return 0, len(crops)

    ok = 0
    fail = 0
    for entry in crops:
        # Soportar tupla 6 u 8 elementos
        if len(entry) == 8:
            target_name, crop_box, w, h, dither, thr, transp, outline = entry
        elif len(entry) == 7:
            target_name, crop_box, w, h, dither, thr, transp = entry
            outline = 0
        else:
            target_name, crop_box, w, h, dither, thr = entry
            transp  = False
            outline = 0

        try:
            img_src = img_raw.convert('RGB')
            cropped = img_src.crop(crop_box)

            if transp:
                result = to_rgba_transparent(cropped, w, h, dither, thr)
                if outline > 0:
                    result = add_outline(result, thickness=outline)
            else:
                result = to_1bit_opaque(cropped, w, h, dither, thr)

            save_result(result, target_name)
            print(f"  ✅ {os.path.basename(source_path):42s} → {target_name} ({w}×{h}) [crop {crop_box}]")
            ok += 1
        except Exception as e:
            print(f"  ❌ Error recortando {target_name}: {e}")
            fail += 1
    return ok, fail

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("=" * 70)
    print("  Plomero Díaz v4.0 — Procesador de Sprites para Playdate")
    print("=" * 70)
    print(f"  Origen  : {ARTIFACT_DIR}")
    print(f"  Destino : {GAME_ASSETS}")
    print()

    success = 0
    failed  = 0

    print("── Sprites simples ──────────────────────────────────────────────────")
    for args in SPRITES:
        if process_sprite(*args):
            success += 1
        else:
            failed += 1

    print()
    print("── Sprites compuestos (recorte desde spritesheet) ───────────────────")
    for (pattern, crops) in COMPOSITE_CROPS:
        ok, fail = process_composite(pattern, crops)
        success += ok
        failed  += fail

    print()
    print(f"  Resultado final: {success} OK  |  {failed} fallidos")
    print()
    if failed > 0:
        print("  NOTA: Los sprites fallidos usarán los fallbacks geométricos del juego.")
        print("  Si los fondos bg_bathroom_1/2/3 no existen por separado, el juego")
        print("  usará bg_bathroom.png genérico como respaldo automáticamente.")
    else:
        print("  ¡Todos los sprites procesados correctamente! Recompila con pdc.")
    print("=" * 70)

if __name__ == '__main__':
    main()
