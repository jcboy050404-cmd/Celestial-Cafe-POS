Add-Type -AssemblyName System.Drawing

function Resize-Image($srcPath, $destPath, $w, $h) {
    $src = [System.Drawing.Image]::FromFile($srcPath)
    $dest = New-Object System.Drawing.Bitmap($w, $h)
    $graphics = [System.Drawing.Graphics]::FromImage($dest)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.DrawImage($src, 0, 0, $w, $h)
    $dest.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $dest.Dispose()
    $src.Dispose()
    Write-Host "Created $destPath ($w x $h)"
}

Resize-Image 'assets/images/jc_pos_logo.png' 'web/favicon.png' 64 64
Resize-Image 'assets/images/jc_pos_logo.png' 'web/icons/Icon-192.png' 192 192
Resize-Image 'assets/images/jc_pos_logo.png' 'web/icons/Icon-512.png' 512 512
Resize-Image 'assets/images/jc_pos_logo.png' 'web/icons/Icon-maskable-192.png' 192 192
Resize-Image 'assets/images/jc_pos_logo.png' 'web/icons/Icon-maskable-512.png' 512 512
