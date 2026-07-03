# ⚠️ HEADS UP: Windows Defender (AMSI) BLOCKS this script as "malicious content" — a script
# that captures the screen and streams it over a socket looks exactly like spyware/RAT
# behaviour, so AV flags it. This is WHY the project uses real RDP (a trusted, signed
# Windows component) instead. This file is kept only as a reference / opt-in lightweight
# mirror. Do NOT try to evade AV. If you genuinely want it, YOU decide to allow it in
# Windows Security. The supported path is Remote Desktop. See docs/MIRROR-CLIENT-PLAN.md.
#
# BlackBerry Bridge — lightweight mirror server (image-based, no RDP client required).
# Captures this laptop's screen, scales to 720 wide, JPEG-encodes, and streams length-
# prefixed frames over TCP 3390 to the BlackBerry app. Not interactive (view only) — a
# stand-in that puts REAL laptop pixels on the phone until a true RDP client is wired.
#
# Run:  powershell -ExecutionPolicy Bypass -File mirror_server.ps1

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$Port = 3390
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
$listener.Start()
Write-Host "mirror: listening on TCP $Port"

# JPEG encoder @ quality 45 (small frames for remote-desktop-ish bandwidth)
$jpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$eps  = New-Object System.Drawing.Imaging.EncoderParameters(1)
$eps.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]45)

while ($true) {
    $client = $listener.AcceptTcpClient()
    Write-Host "mirror: client connected from $($client.Client.RemoteEndPoint)"
    $stream = $client.GetStream()
    try {
        $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $tw = 720
        $th = [int]($b.Height * $tw / $b.Width)
        while ($client.Connected) {
            $full = New-Object System.Drawing.Bitmap($b.Width, $b.Height)
            $g = [System.Drawing.Graphics]::FromImage($full)
            $g.CopyFromScreen($b.X, $b.Y, 0, 0, $full.Size)
            $g.Dispose()

            $small = New-Object System.Drawing.Bitmap($tw, $th)
            $g2 = [System.Drawing.Graphics]::FromImage($small)
            $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g2.DrawImage($full, 0, 0, $tw, $th)
            $g2.Dispose(); $full.Dispose()

            $ms = New-Object System.IO.MemoryStream
            $small.Save($ms, $jpeg, $eps); $small.Dispose()
            $bytes = $ms.ToArray(); $ms.Dispose()

            $len = [BitConverter]::GetBytes([int]$bytes.Length)   # little-endian
            $stream.Write($len, 0, 4)
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush()

            Start-Sleep -Milliseconds 700
        }
    } catch {
        Write-Host "mirror: client gone ($($_.Exception.Message))"
    } finally {
        $client.Close()
    }
}
