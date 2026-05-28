import os
import argparse
from PIL import Image

def process_image(input_path, output_path, width, height, dither=True, threshold=128):
    """
    Procesa una imagen para adaptarla al formato de Playdate (1-bit).
    """
    if not os.path.exists(input_path):
        print(f"Error: El archivo de entrada '{input_path}' no existe.")
        return

    # Cargar imagen
    img = Image.open(input_path)
    
    # Si la imagen tiene canal alfa, la ponemos sobre un fondo blanco (para Playdate, blanco es el fondo)
    if img.mode in ('RGBA', 'LA') or (img.mode == 'P' and 'transparency' in img.info):
        alpha = img.convert('RGBA').split()[-1]
        bg = Image.new("RGBA", img.size, (255, 255, 255, 255))
        bg.paste(img, mask=alpha)
        img = bg.convert('RGB')
    else:
        img = img.convert('RGB')

    # Redimensionar usando LANCZOS para mantener detalles
    img_resized = img.resize((width, height), Image.Resampling.LANCZOS)

    # Convertir a escala de grises
    gray = img_resized.convert('L')

    if dither:
        # Convertir a 1-bit con Dithering (Floyd-Steinberg)
        bw = gray.convert('1')
    else:
        # Convertir a 1-bit sin Dithering (umbral simple)
        bw = gray.point(lambda x: 255 if x > threshold else 0, '1')

    # Playdate SDK maneja transparencia en imágenes 1-bit mediante color indexado
    # o guardando el PNG como grayscale (L) con valores estrictos 0 y 255
    # La mejor forma de compatibilidad es guardarla como escala de grises de 8-bit pero solo usando negro (0) y blanco (255)
    playdate_compatible = bw.convert('L')

    # Asegurar que el directorio de salida existe
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    playdate_compatible.save(output_path, 'PNG')
    print(f"Procesado exitoso: {input_path} -> {output_path} ({width}x{height}, Dither: {dither})")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Procesador de sprites para Playdate 1-bit")
    parser.add_argument("input", help="Ruta de la imagen de entrada")
    parser.add_argument("output", help="Ruta de la imagen de salida (.png)")
    parser.add_argument("width", type=int, help="Ancho objetivo del sprite")
    parser.add_argument("height", type=int, help="Alto objetivo del sprite")
    parser.add_argument("--no-dither", action="store_true", help="Desactiva el dithering (usa umbral simple)")
    parser.add_argument("--threshold", type=int, default=128, help="Umbral para conversión sin dither (0-255)")

    args = parser.parse_args()
    process_image(args.input, args.output, args.width, args.height, not args.no_dither, args.threshold)
