# ─────────────────────────────────────────────────────────────────────────────
#  RiceConsole — agente de Windows del modo consola (lo instala install.ps1).
#
#  Corre al iniciar sesión. Si Linux dejó un pedido en el buzón (la partición
#  EFI de Windows, \rice\request.json):
#    1. lo consume (lo borra para que no se repita en el próximo arranque),
#    2. reconecta la llamada que había en Linux (Google Meet / Discord),
#    3. abre el juego (o la tienda para instalarlo),
#    4. espera a que cierres el juego y pregunta: VOLVER A LINUX / QUEDARME.
#  Sin pedido no hace nada: un arranque normal de Windows no cambia.
#  Registro: C:\ProgramData\RiceConsole\agent.log
# ─────────────────────────────────────────────────────────────────────────────
$ErrorActionPreference = 'Continue'
$Base = Join-Path $env:ProgramData 'RiceConsole'
$Log  = Join-Path $Base 'agent.log'
function Log($m) { Add-Content -Path $Log -Value ('{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $m) -Encoding UTF8 }

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# ── 1. Buzón ─────────────────────────────────────────────────────────────────
function Open-Mailbox {
    foreach ($l in 'R','Q','P','O') {
        if (-not (Test-Path "${l}:\")) {
            mountvol "${l}:" /S 2>$null | Out-Null
            if (Test-Path "${l}:\EFI") { return "${l}:" }
        }
    }
    return $null
}
$esp = Open-Mailbox
if (-not $esp) { Log 'no pude montar la partición EFI'; exit 1 }
$reqFile = Join-Path $esp 'rice\request.json'
if (-not (Test-Path $reqFile)) { mountvol $esp /D | Out-Null; exit 0 }
try {
    $msg = Get-Content $reqFile -Raw -Encoding UTF8 | ConvertFrom-Json
} catch { $msg = $null }
Remove-Item $reqFile -Force -ErrorAction SilentlyContinue
mountvol $esp /D | Out-Null
if (-not $msg) { Log 'pedido ilegible'; exit 1 }
$age = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - [int64]$msg.time
if ($age -gt 1800) { Log "pedido viejo ($age s), se ignora"; exit 0 }
$req = $msg.request
Log "pedido: $($req.action) $($req.title)"

# ── Ventanas con la estética del rice (fósforo verde) ────────────────────────
$Green   = [Drawing.Color]::FromArgb(185, 240, 194)
$Dim     = [Drawing.Color]::FromArgb(79, 148, 102)
$Deep    = [Drawing.Color]::FromArgb(4, 19, 11)
$Warn    = [Drawing.Color]::FromArgb(255, 106, 74)
$FontName = if ((New-Object Drawing.Text.InstalledFontCollection).Families.Name -contains 'DepartureMono Nerd Font') { 'DepartureMono Nerd Font' } else { 'Consolas' }

function Show-Splash($lines, $ms) {
    $f = New-Object Windows.Forms.Form
    $f.FormBorderStyle = 'None'; $f.WindowState = 'Maximized'; $f.TopMost = $true
    $f.BackColor = [Drawing.Color]::Black; $f.ShowInTaskbar = $false
    $lbl = New-Object Windows.Forms.Label
    $lbl.Dock = 'Fill'; $lbl.ForeColor = $Green; $lbl.TextAlign = 'MiddleLeft'
    $lbl.Padding = New-Object Windows.Forms.Padding(120, 0, 0, 0)
    $lbl.Font = New-Object Drawing.Font($FontName, 20)
    $f.Controls.Add($lbl)
    $t = New-Object Windows.Forms.Timer; $t.Interval = 90
    $script:shown = 0
    $t.Add_Tick({
        if ($script:shown -lt $lines.Count) { $script:shown++; $lbl.Text = ($lines[0..($script:shown - 1)] -join "`n") }
    })
    $close = New-Object Windows.Forms.Timer; $close.Interval = $ms
    $close.Add_Tick({ $close.Stop(); $f.Close() })
    $f.Add_Shown({ $t.Start(); $close.Start() })
    [void]$f.ShowDialog()
}

Show-Splash @(
    '> 冬眠モード // ENLACE DESDE LINUX',
    "> PEDIDO: $($req.title.ToUpper())",
    $(if ($msg.call) { '> LLAMADA EN CURSO: RECONECTANDO ....... OK' } else { '> SIN LLAMADA EN CURSO' }),
    '> TRANSFIRIENDO CONTROL .................. OK'
) 1800

# ── 2. Llamada (lo mejor posible: Meet y Discord no tienen "unirse solo") ────
# Busca un botón por nombre en las ventanas de una app y lo aprieta (UI Automation)
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
function Press-Button($procNames, $namesRegex, $timeoutSec) {
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    $root = [Windows.Automation.AutomationElement]::RootElement
    $btnCond = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty, [Windows.Automation.ControlType]::Button)
    while ((Get-Date) -lt $deadline) {
        foreach ($p in Get-Process -Name $procNames -ErrorAction SilentlyContinue | Where-Object MainWindowHandle -ne 0) {
            try {
                $w = [Windows.Automation.AutomationElement]::FromHandle($p.MainWindowHandle)
                foreach ($b in $w.FindAll([Windows.Automation.TreeScope]::Descendants, $btnCond)) {
                    if ($b.Current.Name -match $namesRegex) {
                        $b.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()
                        Log "llamada: apreté '$($b.Current.Name)'"
                        return $true
                    }
                }
            } catch {}
        }
        Start-Sleep -Milliseconds 1500
    }
    Log "llamada: no encontré el botón ($namesRegex)"
    return $false
}

$call = $msg.call
if ($call -and $call.meet) {
    Log "meet: $($call.meet)"
    # Edge con accesibilidad forzada: así UI Automation "ve" el botón de la página
    Start-Process 'msedge.exe' -ArgumentList '--force-renderer-accessibility', '--new-window', $call.meet
}
if ($call -and $call.discord) {
    $d = $call.discord
    if ($d.guild -and $d.channel) {
        Log "discord: $($d.guild)/$($d.channel)"
        Start-Process "discord://-/channels/$($d.guild)/$($d.channel)"
    } else {
        Log 'discord: llamada sin canal conocido, solo se abre Discord'
        Start-Process 'discord://'
    }
}

# ── 3. Abrir el juego / la tienda ────────────────────────────────────────────
function Start-Launch($l) {
    if ($l -match '^"([^"]+)"\s*(.*)$') {                        # "C:\x.exe" args
        Start-Process -FilePath $Matches[1] -ArgumentList $Matches[2] -WorkingDirectory (Split-Path $Matches[1])
    } elseif ($l -match '^shell:') {                             # apps de Xbox
        Start-Process 'explorer.exe' $l
    } elseif ($l -match '^[a-z0-9+.-]+:' -and $l -notmatch '^[A-Za-z]:\\') {   # steam://, uplay://…
        Start-Process $l
    } else {                                                     # C:\juego.exe
        Start-Process -FilePath $l -WorkingDirectory (Split-Path $l)
    }
}
if ($req.action -eq 'install') {
    switch ($req.store) {
        'steam' { Start-Process "steam://install/$($req.steamid)" }
        'epic'  { Start-Process 'com.epicgames.launcher://store/' }
        'gog'   { Start-Process 'C:\Program Files (x86)\GOG Galaxy\GalaxyClient.exe' }
        default { Start-Launch $req.launch }
    }
    Log 'instalación: abierta la tienda, fin'
    exit 0
}
Start-Launch $req.launch
Log "lanzado: $($req.launch)"

# Mientras el juego carga, apretar "Unirse" en Meet / Discord (máx. 90 s cada uno)
if ($call -and $call.meet)    { [void](Press-Button @('msedge')  '^(Unirse ahora|Join now|Solicitar unirse|Ask to join)$' 90) }
if ($call -and $call.discord -and $call.discord.channel) { [void](Press-Button @('Discord') '^(Unirse a la voz|Join Voice|Unirse a la llamada|Join Call|Unirse)$' 90) }

# ── 4. Esperar a que cierres el juego ────────────────────────────────────────
$dirs  = @($req.watch.dirs  | Where-Object { $_ })
$procs = @($req.watch.procs | Where-Object { $_ })
function Game-Running {
    foreach ($p in Get-Process -ErrorAction SilentlyContinue) {
        if ($procs -contains $p.ProcessName) { return $true }
        $path = $null; try { $path = $p.Path } catch {}
        if ($path) { foreach ($d in $dirs) { if ($path.StartsWith($d, [StringComparison]::OrdinalIgnoreCase)) { return $true } } }
    }
    return $false
}
$started = $false
$deadline = (Get-Date).AddMinutes(6)                  # tiempo para que arranque (updates, launcher…)
while (-not $started -and (Get-Date) -lt $deadline) { Start-Sleep 3; $started = Game-Running }
if ($started) {
    Log 'juego en marcha'
    $gone = 0
    while ($gone -lt 5) {                             # 5 chequeos seguidos sin juego (~15 s): cerrado
        Start-Sleep 3
        if (Game-Running) { $gone = 0 } else { $gone++ }
    }
    Log 'juego cerrado'
} else {
    Log 'no detecté el juego en 6 minutos'
}

# ── 5. ¿Volver a Linux? (teclado, mouse o control de Xbox) ──────────────────
Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public static class XPad {
    [StructLayout(LayoutKind.Sequential)] public struct State { public uint Packet; public ushort Buttons; public byte LT, RT; public short LX, LY, RX, RY; }
    [DllImport("xinput1_4.dll")] static extern uint XInputGetState(uint i, out State s);
    public static ushort Buttons() { for (uint i = 0; i < 4; i++) { State s; if (XInputGetState(i, out s) == 0) return s.Buttons; } return 0; }
}
'@

$f = New-Object Windows.Forms.Form
$f.FormBorderStyle = 'None'; $f.WindowState = 'Maximized'; $f.TopMost = $true
$f.BackColor = [Drawing.Color]::Black; $f.KeyPreview = $true
$title = New-Object Windows.Forms.Label
$title.Text = if ($started) { "> SESIÓN TERMINADA: $($req.title.ToUpper())" } else { "> NO DETECTÉ EL JUEGO ($($req.title.ToUpper()))" }
$title.ForeColor = $Dim; $title.Font = New-Object Drawing.Font($FontName, 18)
$title.AutoSize = $true; $title.Location = New-Object Drawing.Point(140, 260)
$q = New-Object Windows.Forms.Label
$q.Text = '¿VOLVER A LINUX?'; $q.ForeColor = $Green; $q.Font = New-Object Drawing.Font($FontName, 42)
$q.AutoSize = $true; $q.Location = New-Object Drawing.Point(134, 310)
$f.Controls.AddRange(@($title, $q))
$buttons = @()
foreach ($t in @('VOLVER A LINUX', 'QUEDARME EN WINDOWS')) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $t; $b.FlatStyle = 'Flat'; $b.Font = New-Object Drawing.Font($FontName, 18)
    $b.Size = New-Object Drawing.Size(420, 70); $b.FlatAppearance.BorderColor = $Dim
    $b.Location = New-Object Drawing.Point((140 + $buttons.Count * 450), 440)
    $buttons += $b
}
$f.Controls.AddRange($buttons)
$hint = New-Object Windows.Forms.Label
$hint.Text = 'A  ELEGIR     ◀ ▶  MOVER     B  QUEDARSE'; $hint.ForeColor = $Dim
$hint.Font = New-Object Drawing.Font($FontName, 13); $hint.AutoSize = $true
$hint.Location = New-Object Drawing.Point(140, 540)
$f.Controls.Add($hint)

$script:sel = 0
$script:choice = 'stay'
function Paint-Sel {
    for ($i = 0; $i -lt 2; $i++) {
        $on = $i -eq $script:sel
        $buttons[$i].BackColor = if ($on) { $Green } else { [Drawing.Color]::Black }
        $buttons[$i].ForeColor = if ($on) { $Deep } else { $Green }
    }
}
$buttons[0].Add_Click({ $script:choice = 'linux'; $f.Close() })
$buttons[1].Add_Click({ $script:choice = 'stay'; $f.Close() })
foreach ($i in 0, 1) { $buttons[$i].Add_MouseEnter({ param($s) $script:sel = [array]::IndexOf($buttons, $s); Paint-Sel }) }
$f.Add_KeyDown({
    param($s, $e)
    switch ($e.KeyCode) {
        'Left'   { $script:sel = 0; Paint-Sel }
        'Right'  { $script:sel = 1; Paint-Sel }
        'Return' { $buttons[$script:sel].PerformClick() }
        'Escape' { $script:choice = 'stay'; $f.Close() }
    }
    $e.Handled = $true
})
# Control: cruceta / A / B (XInput), cada 60 ms; solo flancos (apretar, no mantener)
$script:prev = [XPad]::Buttons()
$pt = New-Object Windows.Forms.Timer; $pt.Interval = 60
$pt.Add_Tick({
    $now = [XPad]::Buttons(); $new = $now -band (-bnot $script:prev); $script:prev = $now
    if ($new -band 0x0004) { $script:sel = 0; Paint-Sel }          # cruceta izquierda
    if ($new -band 0x0008) { $script:sel = 1; Paint-Sel }          # cruceta derecha
    if ($new -band 0x1000) { $buttons[$script:sel].PerformClick() } # A
    if ($new -band 0x2000) { $script:choice = 'stay'; $f.Close() }  # B
})
$f.Add_Shown({ Paint-Sel; $pt.Start(); $f.Activate() })
[void]$f.ShowDialog()
$pt.Stop()
Log "elección: $($script:choice)"

if ($script:choice -eq 'linux') {
    # Próximo arranque (uno solo): la entrada de Linux (Limine) del firmware
    $guid = $null; $blk = @()
    foreach ($line in (bcdedit /enum firmware) + '') {
        if ($line -match '^\s*$') {
            $txt = $blk -join "`n"
            if ($txt -match '(?i)limine' -and $txt -match '\{[0-9a-f-]{36}\}') { $guid = $Matches[0] }
            $blk = @()
        } else { $blk += $line }
    }
    if ($guid) {
        bcdedit /set '{fwbootmgr}' bootsequence $guid | Out-Null
        Log "volviendo a Linux ($guid)"
        Show-Splash @('> 冬眠モード // REGRESANDO A LINUX', '> REINICIANDO ...') 1200
        shutdown.exe /r /t 0
    } else {
        Log 'no encontré la entrada de Linux en bcdedit /enum firmware'
        [Windows.Forms.MessageBox]::Show('No encontré la entrada de Linux (Limine). Reiniciá a mano.', 'RiceConsole') | Out-Null
    }
}
