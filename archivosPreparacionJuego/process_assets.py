#!/usr/bin/env python3
"""
process_assets.py  —  Versión 2.0
Convierte las imágenes generadas por IA al formato 1-bit compatible con Playdate.
Añade soporte para recorte de sprites individuales desde imágenes compuestas (spritesheet).

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
# (glob_pattern, target_filename, width, height, use_dither, threshold)
SPRITES = [
    # ── Personaje Díaz ───────────────────────────────────────────────────────
    ("diaz_idle_*.png",        "diaz_idle.png",           80, 100, True,  128),
    ("diaz_work_1_*.png",      "diaz_work-table-1.png",   80, 100, True,  128),
    ("diaz_work_2_*.png",      "diaz_work-table-2.png",   80, 100, True,  128),
    ("diaz_work_3_*.png",      "diaz_work-table-3.png",   80, 100, True,  128),
    ("diaz_calistenia_*.png",  "diaz_calistenia.png",     80, 100, True,  128),
    ("diaz_lose_*.png",        "diaz_lose.png",           80, 100, True,  128),

    # ── Ambiente ─────────────────────────────────────────────────────────────
    ("toilet_*.png",           "toilet.png",             100, 130, True,  128),
    ("bg_bathroom_*.png",      "bg_bathroom.png",        400, 240, True,  140),  # umbral alto = más blanco

    # ── Olas (sin dither para bordes nítidos ukiyo-e) ────────────────────────
    # Recortadas desde wave_set (imagen compuesta con 3 filas de olas)
    # La imagen compuesta mide ~1024×1024 → cada franja es 1024/3 ≈ 341px de alto
    # Procesadas por la lógica especial WAVE_CROPS más abajo

    # ── Obstáculos ───────────────────────────────────────────────────────────
    ("obs_normal_*.png",       "obs_normal.png",          24,  24, False, 110),
    ("obs_pelo_*.png",         "obs_pelo.png",            24,  24, False, 100),
    ("obs_banana_*.png",       "obs_banana.png",          24,  24, False, 110),
    ("obs_car_red_*.png",      "obs_car_red.png",         24,  24, False, 110),

    # ── Moneda ───────────────────────────────────────────────────────────────
    ("coin_*.png",             "coin.png",                10,  10, False, 100),

    # ── Flush (animación nivel completado) ────────────────────────────────────
    ("flush_1_*.png",          "flush-table-1.png",       90,  90, True,  128),
    ("flush_1_*.png",          "flush-table-2.png",       90,  90, True,  128),
    ("flush_1_*.png",          "flush-table-3.png",       90,  90, True,  128),
    ("flush_1_*.png",          "flush-table-4.png",       90,  90, True,  128),
    ("flush_1_*.png",          "flush-table-5.png",       90,  90, True,  128),

    # ── HUD ──────────────────────────────────────────────────────────────────
    ("ui_water_drop_*.png",    "ui_water_drop.png",       16,  16, False, 100),
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
# (glob_pattern, [(target_filename, crop_box, width, height, use_dither, threshold), ...])
# crop_box: (left, top, right, bottom) en coordenadas de la imagen fuente ORIGINAL (antes de resize)
# La imagen generada de olas es cuadrada (~1024×1024) con 3 franjas horizontales.

COMPOSITE_CROPS = [
    # === Olas desde wave_set_*.png ===
    # Imagen compuesta: 3 franjas de olas apiladas verticalmente
    # Cada franja es aproximadamente 1/3 del alto total
    ("wave_set_*.png", [
        # Ola 1 — franja superior (crestas altas ukiyo-e)
        # Recortar desde y=0 hasta y=340 (aprox 1/3 de 1024)
        ("wave_1.png",   (0,   0, 1024, 340),  96, 32, False, 128),
        # Ola 2 — franja media
        ("wave_2.png",   (0, 340, 1024, 680),  96, 32, False, 128),
        # Ola 3 — franja inferior (ripple suave)
        ("wave_3.png",   (0, 680, 1024, 1024), 96, 32, False, 128),
    ]),

    # === Botones de UI desde ui_arrows_set_*.png ===
    # Imagen compuesta: fila inferior con 5 botones de ~200px c/u en 1024px
    # Los botones están en la mitad inferior de la imagen (filas 400–700 aprox)
    # Fila inferior con todos los botones correctos, en orden: up, down, left, right, A
    # Cada botón ocupa aproximadamente 200px de ancho
    ("ui_arrows_set_*.png", [
        ("ui_arrow_up.png",    (0,   400, 205, 700), 24, 24, False, 100),
        ("ui_arrow_down.png",  (205, 400, 410, 700), 24, 24, False, 100),
        ("ui_arrow_left.png",  (410, 400, 615, 700), 24, 24, False, 100),
        ("ui_arrow_right.png", (615, 400, 820, 700), 24, 24, False, 100),
        ("ui_button_a.png",    (820, 400, 1024,700), 24, 24, False, 100),
    ]),
]

# ── Funciones ─────────────────────────────────────────────────────────────────

def find_source(pattern):
    """Encuentra el archivo más reciente que coincida con el patrón glob."""
    matches = sorted(glob.glob(os.path.join(ARTIFACT_DIR, pattern)))
    return matches[-1] if matches else None

def prepare_image(img):
    """Normaliza el modo de imagen a RGB con fondo blanco."""
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

def to_1bit(img_rgb, width, height, use_dither, threshold, rotation=0):
    """Redimensiona, opcionalmente rota y convierte a 1-bit compatible con Playdate."""
    if rotation != 0:
        img_rgb = img_rgb.rotate(rotation, expand=False, fillcolor=(255, 255, 255))
    img_rgb = img_rgb.resize((width, height), Image.Resampling.LANCZOS)
    gray    = img_rgb.convert('L')
    if use_dither:
        bw = gray.convert('1')  # Floyd-Steinberg
    else:
        bw = gray.point(lambda x: 255 if x > threshold else 0, '1')
    return bw.convert('L')  # 8-bit con solo 0 y 255 (compatibilidad Playdate)

def save_result(result_img, target_name):
    """Guarda la imagen procesada en el directorio de assets del juego."""
    target_path = os.path.join(GAME_ASSETS, target_name)
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    result_img.save(target_path, 'PNG')

def process_sprite(pattern, target_name, width, height, use_dither, threshold):
    """Procesa un sprite simple (sin recorte)."""
    source_path = find_source(pattern)
    if source_path is None:
        print(f"  ⚠️  No encontrado: {pattern}")
        return False
    try:
        img      = prepare_image(Image.open(source_path))
        rotation = FLUSH_ROTATIONS.get(target_name, 0)
        result   = to_1bit(img, width, height, use_dither, threshold, rotation)
        save_result(result, target_name)
        print(f"  ✅ {os.path.basename(source_path):40s} → {target_name} ({width}×{height})")
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
        base_img = prepare_image(Image.open(source_path))
    except Exception as e:
        print(f"  ❌ No se pudo abrir {pattern}: {e}")
        return 0, len(crops)

    ok = 0
    fail = 0
    for (target_name, crop_box, w, h, dither, thr) in crops:
        try:
            cropped = base_img.crop(crop_box)
            result  = to_1bit(cropped, w, h, dither, thr)
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
    print("  Plomero Díaz v2.0 — Procesador de Sprites para Playdate")
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
