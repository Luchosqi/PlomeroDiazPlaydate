#!/usr/bin/env python3
"""
process_assets.py  —  Versión 4.2
Convierte imágenes generadas por IA al formato 1-bit compatible con Playdate.

═══════════════════════════════════════════════════════════════════════════════
CAMBIOS v4.2  (sobre v4.1)
───────────────────────────────────────────────────────────────────────────────
[NEW] Ícono de biblioteca (card.png):
      • Fuente: source/assets/images/IconoJuego32x32/iconoJuego.png (1254×1254)
      • Destino: source/assets/images/card.png  (32×32, sin dithering)
      • Se usa ICON_PATH + process_sprite_from_path() con dither=False
        para que los trazos queden sólidos y nítidos a ese tamaño mínimo.
      • pdxinfo actualizado: imagePath=assets/images/card

CAMBIOS v4.1  (sobre v4.0)
───────────────────────────────────────────────────────────────────────────────
[NEW] Soporte para fondos desde DOS fuentes distintas:
      • ARTIFACT_DIR  → fondo original  (bg_bathroom_1)
      • GAME_ASSETS   → fondo2.png      (bg_bathroom_2)
                        fondo3.png      (bg_bathroom_3)

[FIX] Inodoro (toilet.png): outline 2 → 3 px para igualar visibilidad con Díaz.

Sin cambios en tipografías ni fuentes.
═══════════════════════════════════════════════════════════════════════════════

INSTRUCCIONES DE GENERACIÓN DE IMÁGENES (para la IA generadora)
───────────────────────────────────────────────────────────────────────────────

1. PERSONAJE "DIAZ" → RGBA transparente + outline blanco 3 px (add_outline)
2. INODORO          → RGBA transparente + outline blanco 3 px (add_outline)  ← FIX v4.1
3. bg_bathroom_1    → fondo original desde ARTIFACT_DIR (ladrillos)
   bg_bathroom_2    → fondo2.png desde GAME_ASSETS  (azulejos)               ← NEW v4.1
   bg_bathroom_3    → fondo3.png desde GAME_ASSETS  (grafitis)               ← NEW v4.1
4. Obstáculos       → L 36×36 opaco (el círculo de contraste lo dibuja Lua)
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

# ── Rutas base ───────────────────────────────────────────────────────────────
# ARTIFACT_DIR: donde la IA guarda sus imágenes generadas (fuente principal)
ARTIFACT_DIR = "/home/luchosqi/.gemini/antigravity/brain/bf7b4f31-1cdb-4669-ad27-092621339f70"

# GAME_ASSETS: destino final de todos los sprites procesados
# [v4.1] También se usa como FUENTE para fondo2.png y fondo3.png que el usuario
#         colocó directamente aquí en lugar de en ARTIFACT_DIR.
GAME_ASSETS  = "/home/luchosqi/Documentos/Universidad/semestres/Semestre 5/PRACTICA 1/PlomeroDiaz/source/assets/images"

# ── Rutas directas para los fondos nuevos ────────────────────────────────────
# [v4.1 NEW] fondo2.png y fondo3.png están en GAME_ASSETS (el usuario los colocó ahí).
# Si en el futuro los mueves a ARTIFACT_DIR, cambia estas rutas o usa find_source().
FONDO2_PATH = os.path.join(GAME_ASSETS, "fondo2.png")   # → bg_bathroom_2.png
FONDO3_PATH = os.path.join(GAME_ASSETS, "fondo3.png")   # → bg_bathroom_3.png

# [v4.2 NEW] Ícono de biblioteca — ruta exacta donde el usuario lo colocó.
# El archivo fuente puede ser de cualquier tamaño; se escala a 32×32 sin dithering.
ICON_PATH   = os.path.join(GAME_ASSETS, "IconoJuego32x32", "iconoJuego.png")

# ── Tabla de sprites ──────────────────────────────────────────────────────────
# Columnas: (glob_pattern, target_name, width, height, use_dither, threshold, transparent_bg, outline_px)
#   glob_pattern    → se busca en ARTIFACT_DIR con glob
#   transparent_bg  → True = exporta RGBA (canal alfa real)
#                     False = exporta L 8-bit opaco
#   outline_px > 0  → agrega outline BLANCO N px (solo cuando transparent_bg=True)
SPRITES = [
    # ── Personaje Díaz — RGBA transparente + outline blanco 3 px ─────────────
    ("diaz_idle_*.png",        "diaz_idle.png",           120, 150, True,  128, True,  3),
    ("diaz_work_1_*.png",      "diaz_work-table-1.png",   120, 150, True,  128, True,  3),
    ("diaz_work_2_*.png",      "diaz_work-table-2.png",   120, 150, True,  128, True,  3),
    ("diaz_work_3_*.png",      "diaz_work-table-3.png",   120, 150, True,  128, True,  3),
    ("diaz_calistenia_*.png",  "diaz_calistenia.png",     120, 150, True,  128, True,  3),
    ("diaz_lose_*.png",        "diaz_lose.png",           120, 150, True,  128, True,  3),

    # ── Inodoro — RGBA transparente + outline blanco 3 px ────────────────────
    # [v4.1 FIX] outline subido de 2 → 3 px para igualar la silueta del personaje
    #            y garantizar visibilidad sobre cualquier fondo dithered de muralla.
    ("toilet_*.png",           "toilet.png",              110, 145, True,  128, True,  3),

    # ── Fondo #1 — desde ARTIFACT_DIR (original, ladrillos/baño genérico) ────
    # [v4.1] Este sigue usando el glob estándar sobre ARTIFACT_DIR.
    ("bg_bathroom_*.png",      "bg_bathroom_1.png",       400, 240, True,  130, False, 0),
    # También exportar el genérico por retrocompatibilidad con módulos Lua existentes
    ("bg_bathroom_*.png",      "bg_bathroom.png",         400, 240, True,  130, False, 0),

    # NOTA: bg_bathroom_2 y bg_bathroom_3 se procesan por separado más abajo
    # mediante EXTRA_BACKGROUNDS, usando rutas absolutas directas a GAME_ASSETS.

    # ── Obstáculos — opacos, 36×36 px ────────────────────────────────────────
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

# ── [v4.1/4.2] Assets desde ruta absoluta directa ───────────────────────────
# Formato: (ruta_absoluta_fuente, target_name, width, height, use_dither, threshold)
# Se procesan con process_sprite_from_path() en lugar de process_sprite().
EXTRA_BACKGROUNDS = [
    # [v4.1] fondo2.png → bg_bathroom_2.png  (el usuario lo colocó en GAME_ASSETS)
    (FONDO2_PATH, "bg_bathroom_2.png", 400, 240, True,  130),

    # [v4.1] fondo3.png → bg_bathroom_3.png  (el usuario lo colocó en GAME_ASSETS)
    (FONDO3_PATH, "bg_bathroom_3.png", 400, 240, True,  130),

    # [v4.2 NEW] iconoJuego.png → card.png  (ícono 32×32 en la biblioteca Playdate)
    # dither=False: a 32×32 el dithering destruye los detalles; umbral fijo mejor.
    # threshold=128: punto medio estándar — pixeles < 128 = negro, >= 128 = blanco.
    (ICON_PATH,   "card.png",          32,  32, False, 128),
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

# ── Funciones de utilidad ─────────────────────────────────────────────────────

def find_source(pattern):
    """Busca el archivo más reciente que coincida con el patrón en ARTIFACT_DIR."""
    matches = sorted(glob.glob(os.path.join(ARTIFACT_DIR, pattern)))
    return matches[-1] if matches else None

def prepare_image_rgb(img):
    """Normaliza cualquier modo de imagen a RGB con fondo blanco."""
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
    """Convierte a 1-bit modo L opaco (compatible con Playdate imagetables)."""
    if rotation != 0:
        img_rgb = img_rgb.rotate(rotation, expand=False, fillcolor=(255, 255, 255))
    img_rgb = img_rgb.resize((width, height), Image.Resampling.LANCZOS)
    gray    = img_rgb.convert('L')
    if use_dither:
        bw = gray.convert('1')          # Floyd-Steinberg automático
    else:
        bw = gray.point(lambda x: 255 if x > threshold else 0, '1')
    return bw.convert('L')             # 8-bit (0 ó 255) compatible con pdc

def to_rgba_transparent(img_src, width, height, use_dither, threshold, rotation=0):
    """
    Convierte a RGBA: trazos negros = opacos (alpha=255),
    fondo blanco = transparente (alpha=0).
    Playdate usa el canal alfa del PNG como máscara de recorte del sprite.
    """
    if rotation != 0:
        img_src = img_src.rotate(rotation, expand=False, fillcolor=(255, 255, 255))
    img_src = img_src.resize((width, height), Image.Resampling.LANCZOS)
    gray    = img_src.convert('L')

    if use_dither:
        bw = gray.convert('1').convert('L')
    else:
        bw = gray.point(lambda x: 0 if x <= threshold else 255, 'L')

    rgba     = Image.new('RGBA', bw.size, (255, 255, 255, 0))
    pix_bw   = bw.load()
    pix_rgba = rgba.load()
    w, h     = bw.size
    for y in range(h):
        for x in range(w):
            if pix_bw[x, y] < 128:
                pix_rgba[x, y] = (0, 0, 0, 255)         # trazo negro opaco
            else:
                pix_rgba[x, y] = (255, 255, 255, 0)     # fondo transparente
    return rgba

def add_outline(rgba_img, thickness=3):
    """
    Agrega un outline BLANCO de N píxeles alrededor de los trazos negros.
    Técnica: dilatar el canal alfa → los píxeles nuevos se pintan de blanco opaco.
    Los trazos negros originales permanecen intactos sobre el outline.

    Uso: personaje Díaz (3px) e inodoro (3px) para visibilidad sobre fondos dithered.
    """
    alpha_orig    = rgba_img.split()[3]
    alpha_dilated = alpha_orig
    for _ in range(thickness):
        alpha_dilated = alpha_dilated.filter(ImageFilter.MaxFilter(3))

    orig_pixels    = alpha_orig.load()
    dilated_pixels = alpha_dilated.load()
    result         = rgba_img.copy()
    result_pixels  = result.load()
    w, h           = rgba_img.size

    for y in range(h):
        for x in range(w):
            # Píxel nuevo (parte del outline, NO del trazo original)
            if dilated_pixels[x, y] > 128 and orig_pixels[x, y] < 128:
                result_pixels[x, y] = (255, 255, 255, 255)   # blanco opaco
    return result

def save_result(result_img, target_name):
    """Guarda la imagen procesada en GAME_ASSETS."""
    target_path = os.path.join(GAME_ASSETS, target_name)
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    result_img.save(target_path, 'PNG')

# ── Procesadores principales ──────────────────────────────────────────────────

def process_sprite(pattern, target_name, width, height, use_dither, threshold,
                   transparent_bg=False, outline_px=0):
    """
    Procesa un sprite buscando su fuente en ARTIFACT_DIR via glob.
    Función estándar para la mayoría de los assets.
    """
    source_path = find_source(pattern)
    if source_path is None:
        print(f"  ⚠️  No encontrado en ARTIFACT_DIR: {pattern}")
        return False
    return _process_from_path(source_path, target_name, width, height,
                               use_dither, threshold, transparent_bg, outline_px)

def process_sprite_from_path(source_path, target_name, width, height,
                              use_dither, threshold):
    """
    [v4.1 NEW] Procesa un sprite desde una ruta absoluta directa.
    Se usa para fondo2.png y fondo3.png que están en GAME_ASSETS
    (en lugar de ARTIFACT_DIR).
    Los fondos son siempre opacos (transparent_bg=False, outline_px=0).
    """
    if not os.path.exists(source_path):
        print(f"  ⚠️  Archivo no encontrado: {source_path}")
        return False
    return _process_from_path(source_path, target_name, width, height,
                               use_dither, threshold,
                               transparent_bg=False, outline_px=0)

def _process_from_path(source_path, target_name, width, height,
                        use_dither, threshold, transparent_bg, outline_px):
    """
    Lógica de procesamiento compartida entre process_sprite() y
    process_sprite_from_path(). Acepta la ruta absoluta de la fuente.
    """
    try:
        img_raw  = Image.open(source_path)
        rotation = FLUSH_ROTATIONS.get(target_name, 0)

        if transparent_bg:
            # Exportar como RGBA con fondo transparente
            img_rgb = img_raw.convert('RGB')
            result  = to_rgba_transparent(img_rgb, width, height, use_dither, threshold, rotation)
            # Aplicar outline blanco si se solicita (personaje e inodoro)
            if outline_px > 0:
                result = add_outline(result, thickness=outline_px)
            label = f"RGBA {width}×{height}" + (f" + outline {outline_px}px" if outline_px > 0 else "")
        else:
            # Exportar como L 8-bit opaco (fondos, obstáculos, etc.)
            img_rgb = prepare_image_rgb(img_raw)
            result  = to_1bit_opaque(img_rgb, width, height, use_dither, threshold, rotation)
            label   = f"L 1-bit {width}×{height}"

        save_result(result, target_name)
        src_label = os.path.basename(source_path)
        print(f"  ✅ {src_label:44s} → {target_name} ({label})")
        return True
    except Exception as e:
        print(f"  ❌ Error procesando {os.path.basename(source_path)}: {e}")
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
        # Soportar tupla de 6, 7 u 8 elementos
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
            print(f"  ✅ {os.path.basename(source_path):44s} → {target_name} ({w}×{h}) [crop {crop_box}]")
            ok += 1
        except Exception as e:
            print(f"  ❌ Error recortando {target_name}: {e}")
            fail += 1
    return ok, fail

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("=" * 72)
    print("  Plomero Díaz v4.1 — Procesador de Sprites para Playdate")
    print("=" * 72)
    print(f"  ARTIFACT_DIR : {ARTIFACT_DIR}")
    print(f"  GAME_ASSETS  : {GAME_ASSETS}")
    print()

    success = 0
    failed  = 0

    # ── 1. Sprites estándar (fuente = ARTIFACT_DIR via glob) ──────────────────
    print("── Sprites estándar (desde ARTIFACT_DIR) ────────────────────────────")
    for args in SPRITES:
        if process_sprite(*args):
            success += 1
        else:
            failed += 1

    # ── 2. [v4.1 NEW] Fondos extra (fuente = GAME_ASSETS, rutas directas) ─────
    # fondo2.png → bg_bathroom_2.png  y  fondo3.png → bg_bathroom_3.png
    print()
    print("── Fondos adicionales (desde GAME_ASSETS — rutas directas) ──────────")
    for (src_path, target, w, h, dither, thr) in EXTRA_BACKGROUNDS:
        if process_sprite_from_path(src_path, target, w, h, dither, thr):
            success += 1
        else:
            failed += 1

    # ── 3. Sprites compuestos (spritesheet → cortes individuales) ─────────────
    print()
    print("── Sprites compuestos (recorte desde spritesheet) ───────────────────")
    for (pattern, crops) in COMPOSITE_CROPS:
        ok, fail = process_composite(pattern, crops)
        success += ok
        failed  += fail

    # ── Resumen final ─────────────────────────────────────────────────────────
    print()
    print("=" * 72)
    print(f"  Resultado final: {success} OK  |  {failed} fallidos")
    if failed == 0:
        print("  ¡Todos los sprites procesados correctamente! Recompila con pdc.")
    else:
        print("  Los sprites fallidos usarán los fallbacks geométricos del juego.")
    print("=" * 72)

if __name__ == '__main__':
    main()
