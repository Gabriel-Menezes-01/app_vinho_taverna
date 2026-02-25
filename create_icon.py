from PIL import Image, ImageDraw, ImageFont
import os

# Criar diretório se não existir
os.makedirs('assets/icon', exist_ok=True)

# Criar uma imagem 1024x1024
size = 1024
img = Image.new('RGB', (size, size), color='#6B2737')
draw = ImageDraw.Draw(img)

# Desenhar fundo arredondado
for i in range(size):
    for j in range(size):
        # Criar bordas arredondadas
        if (i < 200 and j < 200 and (i-200)**2 + (j-200)**2 > 200**2) or \
           (i > 824 and j < 200 and (i-824)**2 + (j-200)**2 > 200**2) or \
           (i < 200 and j > 824 and (i-200)**2 + (j-824)**2 > 200**2) or \
           (i > 824 and j > 824 and (i-824)**2 + (j-824)**2 > 200**2):
            img.putpixel((i, j), (107, 39, 55))

# Desenhar corpo da garrafa
bottle_color = '#8B1538'
draw.ellipse([392, 350, 632, 400], fill=bottle_color, outline='white', width=8)
draw.rectangle([392, 375, 632, 900], fill=bottle_color, outline='white', width=8)
draw.ellipse([392, 875, 632, 925], fill=bottle_color, outline='white', width=8)

# Desenhar gargalo
draw.rectangle([462, 200, 562, 375], fill=bottle_color, outline='white', width=8)

# Desenhar tampa
draw.ellipse([457, 180, 567, 220], fill='#D4AF37', outline='white', width=6)

# Desenhar rótulo
label_color = '#F5E6D3'
draw.rounded_rectangle([422, 550, 602, 730], radius=15, fill=label_color, outline='white', width=4)

# Texto no rótulo (simulado com formas geométricas básicas)
# VT
text_color = '#6B2737'
# V
draw.polygon([(445, 590), (475, 650), (490, 620), (505, 650), (535, 590), (510, 590), (490, 630), (470, 590)], fill=text_color)
# T
draw.rectangle([545, 590, 575, 650], fill=text_color)
draw.rectangle([530, 590, 590, 610], fill=text_color)

# TAVERNA (texto simplificado)
try:
    font = ImageFont.truetype("arial.ttf", 24)
except:
    font = ImageFont.load_default()

draw.text((512, 680), "TAVERNA", fill='#8B1538', anchor='mm', font=font)

# Uvas decorativas
grape_color = '#8B1538'
grape_positions = [(455, 695), (468, 688), (481, 695), (543, 695), (556, 688), (569, 695)]
for pos in grape_positions:
    draw.ellipse([pos[0]-8, pos[1]-8, pos[0]+8, pos[1]+8], fill=grape_color)

# Salvar
img.save('assets/icon/app_icon.png')
print("✓ Ícone criado com sucesso: assets/icon/app_icon.png")
