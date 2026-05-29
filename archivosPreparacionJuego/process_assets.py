#!/usr/bin/env python3
"""
process_assets.py  —  Versión 3.0
Convierte imágenes generadas por IA al formato 1-bit compatible con Playdate.

Cambios v3.0:
  - Los sprites de personaje e inodoro se exportan con CANAL ALFA (RGBA)
    para que el fondo blanco sea transparente → no tapa el fondo de muralla.
  - Tamaño de los sprites del personaje aumentado x1.5 (80→120 px ancho, 100→150 px alto).
  - Soporte para múltiples fondos de baño (bg_bathroom_1/2/3.png).
  - Mantiene todo lo demás (olas, botones UI, obstáculos, flush, etc.).

Uso:
    cd PlomeroDiaz/
    python3 archivosPreparacionJuego/process_assets.py

Requisitos:
    pip install Pillow
"""

import os
import glob
from PIL import Image

# ── Rutas ────────────────────────────────────────────────────────────────────
ARTIFACT_DIR = "/home/luchosqi/.gemini/antigravity/brain/bf7b4f31-1cdb-4669-ad27-092621339f70"
GAME_ASSETS  = "/home/luchosqi/Documentos/Universidad/semestres/Semestre 5/PRACTICA 1/PlomeroDiaz/source/assets/images"

# ── Tabla de sprites simples ──────────────────────────────────────────────────
# (glob_pattern, target_filename, width, height, use_dither, threshold, transparent_bg)
#   transparent_bg=True  → exporta en modo RGBA (fondo transparente, trazos negros)
#   transparent_bg=False → exporta en modo L (1-bit opaco, compatible con imagetables)
SPRITES = [
    # ── Personaje Díaz — 1.5× el tamaño original, fondo transparente ──────────
    ("diaz_idle_*.png",        "diaz_idle.png",           120, 150, True,  128, True),
    ("diaz_work_1_*.png",      "diaz_work-table-1.png",   120, 150, True,  128, True),
    ("diaz_work_2_*.png",      "diaz_work-table-2.png",   120, 150, True,  128, True),
    ("diaz_work_3_*.png",      "diaz_work-table-3.png",   120, 150, True,  128, True),
    ("diaz_calistenia_*.png",  "diaz_calistenia.png",     120, 150, True,  128, True),
    ("diaz_lose_*.png",        "diaz_lose.png",           120, 150, True,  128, True),

    # ── Ambiente — inodoro con fondo transparente ─────────────────────────────
    ("toilet_*.png",           "toilet.png",             110, 145, True,  128, True),

    # ── Fondos de baño × 3 (opacos, llenan toda la pantalla) ─────────────────
    # Se usa el mismo archivo fuente para los 3 niveles.
    # Si tienes 3 imágenes distintas, renómbralas bg_bathroom_1_*.png, etc.
    ("bg_bathroom_*.png",      "bg_bathroom_1.png",      400, 240, True,  140, False),
    ("bg_bathroom_*.png",      "bg_bathroom_2.png",      400, 240, True,  130, False),  # umbral ligeramente diferente
    ("bg_bathroom_*.png",      "bg_bathroom_3.png",      400, 240, True,  150, False),  # más oscuro
    # También exportar el genérico por si algún módulo lo llama directamente
    ("bg_bathroom_*.png",      "bg_bathroom.png",        400, 240, True,  140, False),

    # ── Obstáculos (opacos, 1-bit) ────────────────────────────────────────────
    ("obs_normal_*.png",       "obs_normal.png",          28,  28, False, 110, False),
    ("obs_pelo_*.png",         "obs_pelo.png",            28,  28, False, 100, False),
    ("obs_banana_*.png",       "obs_banana.png",          28,  28, False, 110, False),
    ("obs_car_red_*.png",      "obs_car_red.png",         28,  28, False, 110, False),

    # ── Moneda ────────────────────────────────────────────────────────────────
    ("coin_*.png",             "coin.png",                10,  10, False, 100, False),

    # ── Flush (animación nivel completado) ────────────────────────────────────
    ("flush_1_*.png",          "flush-table-1.png",       90,  90, True,  128, False),
    ("flush_1_*.png",          "flush-table-2.png",       90,  90, True,  128, False),
    ("flush_1_*.png",          "flush-table-3.png",       90,  90, True,  128, False),
    ("flush_1_*.png",          "flush-table-4.png",       90,  90, True,  128, False),
    ("flush_1_*.png",          "flush-table-5.png",       90,  90, True,  128, False),

    # ── HUD ───────────────────────────────────────────────────────────────────
    ("ui_water_drop_*.png",    "ui_water_drop.png",       16,  16, False, 100, False),
]

# Rotaciones para los frames del flush
FLUSH_ROTATIONS = {
    "flush-table-1.png": 0,
    "flush-table-2.png": 72,
    "flush-table-3.png": 144,
    "flush-table-4.png": 216,
    "flush-table-5.png": 288,
}

# ── Recortes especiales desde imágenes compuestas ────────────────────────────
# (glob_pattern, [(target_filename, crop_box, width, height, use_dither, threshold, transparent_bg), ...])

COMPOSITE_CROPS = [
    # === Olas desde wave_set_*.png ===
    ("wave_set_*.png", [
        ("wave_1.png",   (0,   0, 1024, 340),  96, 32, False, 128, False),
        ("wave_2.png",   (0, 340, 1024, 680),  96, 32, False, 128, False),
        ("wave_3.png",   (0, 680, 1024, 1024), 96, 32, False, 128, False),
    ]),

    # === Botones de UI desde ui_arrows_set_*.png ===
    ("ui_arrows_set_*.png", [
        ("ui_arrow_up.png",    (0,   400, 205, 700), 24, 24, False, 100, False),
        ("ui_arrow_down.png",  (205, 400, 410, 700), 24, 24, False, 100, False),
        ("ui_arrow_left.png",  (410, 400, 615, 700), 24, 24, False, 100, False),
        ("ui_arrow_right.png", (615, 400, 820, 700), 24, 24, False, 100, False),
        ("ui_button_a.png",    (820, 400, 1024,700), 24, 24, False, 100, False),
    ]),
]

# ── Funciones ─────────────────────────────────────────────────────────────────

def find_source(pattern):
    """Encuentra el archivo más reciente que coincida con el patrón glob."""
    matches = sorted(glob.glob(os.path.join(ARTIFACT_DIR, pattern)))
    return matches[-1] if matches else None

def prepare_image_rgb(img):
    """Normaliza la imagen a RGB con fondo blanco (para exportación opaca)."""
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
    """Redimensiona y convierte a 1-bit (modo L, 0/255). Exportación opaca."""
    if rotation != 0:
        img_rgb = img_rgb.rotate(rotation, expand=False, fillcolor=(255, 255, 255))
    img_rgb = img_rgb.resize((width, height), Image.Resampling.LANCZOS)
    gray    = img_rgb.convert('L')
    if use_dither:
        bw = gray.convert('1')  # Floyd-Steinberg
    else:
        bw = gray.point(lambda x: 255 if x > threshold else 0, '1')
    return bw.convert('L')  # 8-bit compatible con Playdate

def to_rgba_transparent(img_src, width, height, use_dither, threshold, rotation=0):
    """
    Convierte a RGBA: los píxeles negros (trazos) quedan opacos,
    los blancos (fondo) quedan transparentes.
    Playdate lee el canal alfa del PNG para determinar la máscara de transparencia.
    """
    if rotation != 0:
        img_src = img_src.rotate(rotation, expand=False, fillcolor=(255, 255, 255))
    img_src = img_src.resize((width, height), Image.Resampling.LANCZOS)

    # Convertir a escala de grises primero
    gray = img_src.convert('L')

    # Binarizar
    if use_dither:
        bw = gray.convert('1').convert('L')  # Floyd-Steinberg → L
    else:
        bw = gray.point(lambda x: 0 if x <= threshold else 255, 'L')

    # Construir imagen RGBA:
    #   R=G=B=0 (negro), A=255 donde el píxel es negro (trazo)
    #   R=G=B=255 (blanco), A=0 donde el píxel es blanco (transparente)
    rgba = Image.new('RGBA', bw.size, (255, 255, 255, 0))
    pixels_bw   = bw.load()
    pixels_rgba = rgba.load()
    w, h = bw.size
    for y in range(h):
        for x in range(w):
            val = pixels_bw[x, y]
            if val < 128:  # píxel negro → trazo opaco
                pixels_rgba[x, y] = (0, 0, 0, 255)
            else:           # píxel blanco → transparente
                pixels_rgba[x, y] = (255, 255, 255, 0)
    return rgba

def save_result(result_img, target_name):
    """Guarda la imagen procesada en el directorio de assets del juego."""
    target_path = os.path.join(GAME_ASSETS, target_name)
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    result_img.save(target_path, 'PNG')

def process_sprite(pattern, target_name, width, height, use_dither, threshold, transparent_bg=False):
    """Procesa un sprite simple (sin recorte)."""
    source_path = find_source(pattern)
    if source_path is None:
        print(f"  ⚠️  No encontrado: {pattern}")
        return False
    try:
        img_raw  = Image.open(source_path)
        rotation = FLUSH_ROTATIONS.get(target_name, 0)

        if transparent_bg:
            # Usar src original con alfa si existe, o convertir a RGBA
            if img_raw.mode not in ('RGBA', 'LA', 'P'):
                img_src = img_raw.convert('RGB')
            else:
                img_src = img_raw
            result = to_rgba_transparent(img_src if img_raw.mode == 'RGB' else img_raw.convert('RGB'),
                                         width, height, use_dither, threshold, rotation)
        else:
            img_rgb = prepare_image_rgb(img_raw)
            result  = to_1bit_opaque(img_rgb, width, height, use_dither, threshold, rotation)

        save_result(result, target_name)
        mode_label = "RGBA transparente" if transparent_bg else f"L {width}×{height}"
        print(f"  ✅ {os.path.basename(source_path):40s} → {target_name} ({mode_label})")
        return True
    except Exception as e:
        print(f"  ❌ Error en {pattern}: {e}")
        return False

def process_composite(pattern, crops):
    """Recorta múltiples sprites desde una sola imagen compuesta (spritesheet)."""
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
        # Soporte para tupla de 6 o 7 elementos
        if len(entry) == 7:
            target_name, crop_box, w, h, dither, thr, transp = entry
        else:
            target_name, crop_box, w, h, dither, thr = entry
            transp = False

        try:
            if transp:
                img_src = img_raw.convert('RGB')
            else:
                img_src = prepare_image_rgb(img_raw)

            cropped = img_src.crop(crop_box)

            if transp:
                result = to_rgba_transparent(cropped, w, h, dither, thr)
            else:
                result = to_1bit_opaque(cropped, w, h, dither, thr)

            save_result(result, target_name)
            print(f"  ✅ {os.path.basename(source_path):40s} → {target_name} ({w}×{h})  [recorte {crop_box}]")
            ok += 1
        except Exception as e:
            print(f"  ❌ Error recortando {target_name} de {pattern}: {e}")
            fail += 1
    return ok, fail

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("=" * 65)
    print("  Plomero Díaz v3.0 — Procesador de Sprites para Playdate")
    print("=" * 65)
    print(f"  Origen  : {ARTIFACT_DIR}")
    print(f"  Destino : {GAME_ASSETS}")
    print()

    success = 0
    failed  = 0

    print("── Sprites simples ──────────────────────────────────────────")
    for args in SPRITES:
        if process_sprite(*args):
            success += 1
        else:
            failed += 1

    print()
    print("── Sprites compuestos (recorte desde spritesheet) ───────────")
    for (pattern, crops) in COMPOSITE_CROPS:
        ok, fail = process_composite(pattern, crops)
        success += ok
        failed  += fail

    print()
    print(f"  Resultado: {success} OK  |  {failed} fallidos")
    print()
    if failed > 0:
        print("  NOTA: Los sprites faltantes usarán fallbacks geométricos en el juego.")
    else:
        print("  ¡Todos los sprites procesados correctamente! Recompila con pdc.")
    print("=" * 65)

if __name__ == '__main__':
    main()
