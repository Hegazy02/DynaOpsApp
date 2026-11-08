# Copies the guide screenshots into the repo, cropping away private chat/app content
# and masking the username. Originals are left untouched.
param([string]$Src, [string]$Dst)
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $Dst | Out-Null

# name => crop rectangle (x, y, w, h); names not listed are copied whole.
$crops = @{
  1 = @(0, 560, 738, 180)    # APK file bubble only
  2 = @(0, 850, 738, 720)    # "This file may be harmful" sheet
  3 = @(0, 1150, 738, 420)   # "Install this app?" dialog
  4 = @(0, 355, 738, 935)    # Play Protect dialog
  5 = @(0, 295, 738, 1050)   # Play Protect expanded
  6 = @(0, 1150, 738, 420)   # "App installed" dialog
  7 = @(420, 1130, 170, 190) # the DynaOps launcher icon only
}

$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$params = New-Object System.Drawing.Imaging.EncoderParameters 1
$params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 85L

foreach ($n in 1..23) {
  $img = [System.Drawing.Bitmap]::FromFile((Join-Path $Src "$n.jpeg"))
  if ($crops.ContainsKey($n)) {
    $c = $crops[$n]
    $out = $img.Clone((New-Object System.Drawing.Rectangle $c[0], $c[1], $c[2], $c[3]), $img.PixelFormat)
  } else {
    $out = New-Object System.Drawing.Bitmap $img
  }
  if ($n -eq 9) {
    # Mask the real username in the sign-in field.
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(232, 240, 254))), 110, 645, 400, 58)
    $g.Dispose()
  }
  $out.Save((Join-Path $Dst ("{0:D2}.jpg" -f $n)), $codec, $params)
  $out.Dispose(); $img.Dispose()
}
Get-ChildItem $Dst | Select-Object Name, Length
