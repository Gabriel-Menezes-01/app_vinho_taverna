Add-Type -AssemblyName System.Drawing

# Criar diretório se não existir
$iconDir = "assets\icon"
if (-not (Test-Path $iconDir)) {
    New-Item -ItemType Directory -Path $iconDir -Force | Out-Null
}

# Criar bitmap 1024x1024
$size = 1024
$bitmap = New-Object System.Drawing.Bitmap($size, $size)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

# Cores
$bgColor = [System.Drawing.Color]::FromArgb(107, 39, 55)      # Vinho escuro
$bottleColor = [System.Drawing.Color]::FromArgb(139, 21, 56)  # Vinho médio
$capColor = [System.Drawing.Color]::FromArgb(212, 175, 55)    # Dourado
$labelColor = [System.Drawing.Color]::FromArgb(245, 230, 211) # Bege
$whiteColor = [System.Drawing.Color]::White

# Preencher fundo com cor de vinho
$graphics.Clear($bgColor)

# Desenhar corpo da garrafa
$bottleBrush = New-Object System.Drawing.SolidBrush($bottleColor)
$whitePen = New-Object System.Drawing.Pen($whiteColor, 8)

# Corpo principal
$graphics.FillEllipse($bottleBrush, 392, 350, 240, 50)
$graphics.FillRectangle($bottleBrush, 392, 375, 240, 525)
$graphics.FillEllipse($bottleBrush, 392, 875, 240, 50)

# Bordas
$graphics.DrawEllipse($whitePen, 392, 350, 240, 50)
$graphics.DrawLine($whitePen, 392, 375, 392, 900)
$graphics.DrawLine($whitePen, 632, 375, 632, 900)
$graphics.DrawEllipse($whitePen, 392, 875, 240, 50)

# Gargalo
$graphics.FillRectangle($bottleBrush, 462, 200, 100, 175)
$graphics.DrawRectangle($whitePen, 462, 200, 100, 175)

# Tampa dourada
$capBrush = New-Object System.Drawing.SolidBrush($capColor)
$graphics.FillEllipse($capBrush, 457, 180, 110, 40)
$capPen = New-Object System.Drawing.Pen($whiteColor, 6)
$graphics.DrawEllipse($capPen, 457, 180, 110, 40)

# Rótulo
$labelBrush = New-Object System.Drawing.SolidBrush($labelColor)
$labelRect = New-Object System.Drawing.Rectangle(422, 550, 180, 180)
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddArc($labelRect.X, $labelRect.Y, 30, 30, 180, 90)
$path.AddArc($labelRect.Right - 30, $labelRect.Y, 30, 30, 270, 90)
$path.AddArc($labelRect.Right - 30, $labelRect.Bottom - 30, 30, 30, 0, 90)
$path.AddArc($labelRect.X, $labelRect.Bottom - 30, 30, 30, 90, 90)
$path.CloseFigure()
$graphics.FillPath($labelBrush, $path)

# Texto VT no rótulo
$font = New-Object System.Drawing.Font("Arial", 48, [System.Drawing.FontStyle]::Bold)
$textBrush = New-Object System.Drawing.SolidBrush($bgColor)
$textFormat = New-Object System.Drawing.StringFormat
$textFormat.Alignment = [System.Drawing.StringAlignment]::Center
$textFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
$graphics.DrawString("VT", $font, $textBrush, 512, 610, $textFormat)

# Texto TAVERNA
$smallFont = New-Object System.Drawing.Font("Arial", 24, [System.Drawing.FontStyle]::Regular)
$smallTextBrush = New-Object System.Drawing.SolidBrush($bottleColor)
$graphics.DrawString("TAVERNA", $smallFont, $smallTextBrush, 512, 660, $textFormat)

# Uvas decorativas
$grapeBrush = New-Object System.Drawing.SolidBrush($bottleColor)
$grapeSize = 12
$grapePositions = @(
    @(455, 695), @(472, 688), @(489, 695),
    @(535, 695), @(552, 688), @(569, 695)
)
foreach ($pos in $grapePositions) {
    $graphics.FillEllipse($grapeBrush, $pos[0] - $grapeSize/2, $pos[1] - $grapeSize/2, $grapeSize, $grapeSize)
}

# Salvar
$iconPath = "$iconDir\app_icon.png"
$bitmap.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Limpar recursos
$graphics.Dispose()
$bitmap.Dispose()

Write-Host "Icone criado com sucesso: $iconPath" -ForegroundColor Green
