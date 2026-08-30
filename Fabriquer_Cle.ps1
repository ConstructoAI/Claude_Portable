<#
    Fabriquer_Cle.ps1
    Assemble une cle « Claude Portable - Gestionnaire IA ».

    S'execute UNE FOIS, sur un poste connecte. C'est le seul moment ou
    quelque chose se telecharge : la cle, elle, ne telechargera jamais rien.

    Il verifie son propre travail avant de dire « termine ». Chaque echec
    a son message et sa marche a suivre - il ne pretend jamais avoir
    installe ce qu'il n'a pas installe.

    Une gracieusete de Sylvain Leduc - Constructo AI inc.

    Exemples :
      .\Fabriquer_Cle.ps1 -Cle E:\ -Profil personnelle -SourceGestionnaire C:\chemin\Gestionnaire-IA
      .\Fabriquer_Cle.ps1 -Cle E:\ -Profil demonstration -SourceGestionnaire C:\chemin\Gestionnaire-IA
#>

param(
    [Parameter(Mandatory = $true)][string]$Cle,
    [Parameter(Mandatory = $true)][ValidateSet('personnelle', 'demonstration')][string]$Profil,
    [Parameter(Mandatory = $true)][string]$SourceGestionnaire,
    [string]$PythonVersion = '3.13.1',
    [string]$GitVersion    = '2.54.0'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

function Etape($t) { Write-Host "`n[~] $t" -ForegroundColor Yellow }
function Bon($t)   { Write-Host "    [OK] $t"  -ForegroundColor Green }
function Mal($t)   { Write-Host "    [X]  $t"  -ForegroundColor Red }
function Note($t)  { Write-Host "    $t"       -ForegroundColor DarkGray }

Write-Host "`n=========================================================" -ForegroundColor Cyan
Write-Host "  Claude Portable - Gestionnaire IA : fabrication" -ForegroundColor White
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "  Cible  : $Cle"
Write-Host "  Profil : $Profil"

# ---------------------------------------------------------------- 0. Cible
if (-not (Test-Path -LiteralPath $Cle)) { throw "Cible introuvable : $Cle" }
$Cle = (Resolve-Path -LiteralPath $Cle).Path
if (-not (Test-Path -LiteralPath $SourceGestionnaire)) { throw "Source Gestionnaire-IA introuvable : $SourceGestionnaire" }
$SourceClaudeDir = Join-Path $SourceGestionnaire '.claude'
if (-not (Test-Path -LiteralPath $SourceClaudeDir)) { throw "Dossier .claude absent de $SourceGestionnaire" }

Etape 'Espace disponible'
$lettre = ($Cle -split ':')[0]
$vol = Get-PSDrive -Name $lettre -ErrorAction SilentlyContinue
if ($vol) {
    $libreGo = [math]::Round($vol.Free / 1GB, 1)
    Note "$libreGo Go libres"
    if ($libreGo -lt 2) { throw "Moins de 2 Go libres sur $Cle. Il en faut environ 1,5 Go." }
    Bon 'espace suffisant'
} else {
    Note 'volume non interrogeable - verification ignoree'
}

$dTravail = Join-Path $env:TEMP ("cle_gia_" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $dTravail | Out-Null

# ---------------------------------------------------- 1. Le profil metier
# 🔴 Verrou de confidentialite. Une cle de demonstration ne doit porter
#    NI la memoire accumulee (etat client, decisions, engagements),
#    NI le profil de prix (coefficients cost-plus, taux CCQ).
#    Le script REFUSE de fabriquer plutot que de laisser passer.
Etape 'Controle du contenu selon le profil'

$fichiersMemoire = @(
    'ETAT_projets.md', 'ETAT_calendrier.md',
    'ETAT_courriels_poste.md', 'ETAT_comptabilite.md'
)

if ($Profil -eq 'demonstration') {
    $souilles = @()
    foreach ($f in $fichiersMemoire) {
        $p = Join-Path $SourceClaudeDir $f
        if (Test-Path -LiteralPath $p) {
            $contenu = Get-Content -LiteralPath $p -Raw
            # Un gabarit vierge porte encore ses marqueurs A COMPLETER.
            # Sans marqueur, on considere le fichier rempli : on ne devine pas.
            if ($contenu -notmatch 'A COMPL|À COMPL|GABARIT') { $souilles += $f }
        }
    }
    if ($souilles.Count -gt 0) {
        Mal 'Fabrication refusee.'
        Note "Ces fichiers de memoire ne sont pas vierges : $($souilles -join ', ')"
        Note 'Une cle de demonstration ne peut pas emporter la memoire de vos clients.'
        Note 'Repartez des gabarits du depot, ou fabriquez une cle -Profil personnelle.'
        throw 'Contenu confidentiel detecte dans un profil demonstration.'
    }
    Bon 'memoire vierge - conforme au profil demonstration'
} else {
    Note 'profil personnel : memoire et profil de prix embarques'
}

# ------------------------------------------------------------- 2. claude.exe
Etape 'Claude Code'
$src = (Get-Command claude -ErrorAction SilentlyContinue)
if (-not $src) { throw "claude introuvable dans le PATH. Installez Claude Code sur ce poste d'abord." }
$srcExe = $src.Source
if ($srcExe -like '*.cmd' -or $srcExe -like '*.ps1') {
    $cand = Get-ChildItem -Path (Split-Path -Parent $srcExe) -Filter 'claude.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cand) { $srcExe = $cand.FullName }
}
$srcDir = Split-Path -Parent $srcExe
Note "source : $srcDir"

$dstClaude = Join-Path $Cle 'claude'
if (Test-Path -LiteralPath $dstClaude) { Remove-Item -LiteralPath $dstClaude -Recurse -Force }
Copy-Item -LiteralPath $srcDir -Destination $dstClaude -Recurse -Force
Bon 'copie faite'

# ----------------------------------------------------- 3. Python embeddable
Etape "Python $PythonVersion (embeddable)"
$dstPy = Join-Path $Cle 'python'
if (Test-Path -LiteralPath $dstPy) { Remove-Item -LiteralPath $dstPy -Recurse -Force }
$zipPy = Join-Path $dTravail 'python-embed.zip'
$urlPy = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-amd64.zip"
Note $urlPy
Invoke-WebRequest -Uri $urlPy -OutFile $zipPy -UseBasicParsing
Expand-Archive -LiteralPath $zipPy -DestinationPath $dstPy -Force
Bon 'extrait'

if ($Profil -eq 'personnelle') {
    Etape 'pywin32 (mode complet uniquement)'
    $pth = Get-ChildItem -Path $dstPy -Filter 'python*._pth' | Select-Object -First 1
    if ($pth) {
        $l = Get-Content -LiteralPath $pth.FullName
        if ($l -notcontains 'Lib\site-packages') {
            Add-Content -LiteralPath $pth.FullName -Value 'Lib\site-packages'
        }
        Note "$($pth.Name) : site-packages active"
    }
    $sp = Join-Path $dstPy 'Lib\site-packages'
    New-Item -ItemType Directory -Force -Path $sp | Out-Null
    Note 'Deposez-y le wheel pywin32 (cp313-win_amd64) decompresse.'
    Note 'Mesure M3 du brief : ce point n est pas encore verifie.'
}

# ------------------------------------------------------------ 4. GitPortable
Etape "GitPortable $GitVersion"
$dstGit = Join-Path $Cle 'git'
if (Test-Path -LiteralPath $dstGit) { Remove-Item -LiteralPath $dstGit -Recurse -Force }
$exeGit = Join-Path $dTravail 'GitPortable.exe'
$urlGit = "https://github.com/git-for-windows/git/releases/download/v$GitVersion.windows.1/PortableGit-$GitVersion-64-bit.7z.exe"
Note $urlGit
Invoke-WebRequest -Uri $urlGit -OutFile $exeGit -UseBasicParsing
& $exeGit "-o$dstGit" -y | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $dstGit 'bin\bash.exe'))) {
    throw "Extraction de GitPortable incomplete : bin\bash.exe absent."
}
Bon 'extrait'

# ------------------------------------------------------------- 5. La charge
Etape 'Couche .claude'
$dstProjet = Join-Path $Cle '.claude'
if (Test-Path -LiteralPath $dstProjet) { Remove-Item -LiteralPath $dstProjet -Recurse -Force }
Copy-Item -LiteralPath $SourceClaudeDir -Destination $dstProjet -Recurse -Force

$ga = Join-Path $SourceGestionnaire '.gitattributes'
if (Test-Path -LiteralPath $ga) { Copy-Item -LiteralPath $ga -Destination $Cle -Force }

if ($Profil -eq 'demonstration') {
    # Le profil de prix ne voyage pas.
    $profils = Join-Path $dstProjet 'profiles'
    if (Test-Path -LiteralPath $profils) { Remove-Item -LiteralPath $profils -Recurse -Force }
    # Permissions prudentes sur une machine qui n'est pas la votre.
    $sj = Join-Path $dstProjet 'settings.json'
    if (Test-Path -LiteralPath $sj) {
        (Get-Content -LiteralPath $sj -Raw).Replace('"bypassPermissions"', '"default"') |
            Set-Content -LiteralPath $sj -Encoding UTF8 -NoNewline
        Note 'settings.json : defaultMode ramene a "default"'
    }
    Bon 'profil de prix retire, permissions prudentes'
} else {
    Bon 'couche complete'
}

New-Item -ItemType Directory -Force -Path (Join-Path $Cle 'data') | Out-Null

# ------------------------------------------------------------- 6. Le lanceur
Etape 'Lanceur'
$srcBat = Join-Path $PSScriptRoot 'Constructo_AI.bat'
if (-not (Test-Path -LiteralPath $srcBat)) { throw "Constructo_AI.bat introuvable a cote de ce script." }
Copy-Item -LiteralPath $srcBat -Destination $Cle -Force
Bon 'copie'

# --------------------------------------------- 7. Verification du travail
# Le script ne dit « termine » qu'apres avoir constate, pas suppose.
Etape 'Verification'
$echecs = @()

$attendus = @(
    'claude\claude.exe', 'python\python.exe',
    'git\bin\bash.exe', '.claude\CLAUDE.md', 'Constructo_AI.bat'
)
foreach ($rel in $attendus) {
    $p = Join-Path $Cle $rel
    if (-not (Test-Path -LiteralPath $p)) { $echecs += "absent : $rel"; continue }
    if ((Get-Item -LiteralPath $p).Length -eq 0) { $echecs += "vide : $rel" }
}

# claude.exe relocalise repond-il ? (mesure M1 du brief, faite ici)
$vClaude = & (Join-Path $Cle 'claude\claude.exe') --version 2>&1
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($vClaude)) {
    $echecs += "claude.exe copie ne repond pas. Sortie : $vClaude"
} else {
    Bon "claude.exe : $vClaude"
}

# Python : le faire EXECUTER, pas constater sa presence.
$vPy = & (Join-Path $Cle 'python\python.exe') -c "import sys; print(sys.version.split()[0])" 2>&1
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($vPy)) {
    $echecs += "python.exe ne s'execute pas. Sortie : $vPy"
} else {
    Bon "python.exe : $vPy"
}

# ost_reader : bibliotheque standard seulement, doit repondre partout.
$ost = Join-Path $Cle '.claude\scripts\ost_reader.py'
if (Test-Path -LiteralPath $ost) {
    $null = & (Join-Path $Cle 'python\python.exe') $ost --help 2>&1
    if ($LASTEXITCODE -ne 0) { $echecs += 'ost_reader.py --help a echoue.' } else { Bon 'ost_reader.py repond' }
}

Remove-Item -LiteralPath $dTravail -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
if ($echecs.Count -gt 0) {
    Write-Host '=========================================================' -ForegroundColor Red
    Write-Host '  FABRICATION INCOMPLETE' -ForegroundColor Red
    Write-Host '=========================================================' -ForegroundColor Red
    foreach ($e in $echecs) { Mal $e }
    Write-Host "`n  La cle n'est pas utilisable en l'etat. Rien n'est masque." -ForegroundColor Red
    exit 1
}

Write-Host '=========================================================' -ForegroundColor Green
Write-Host '  CLE PRETE' -ForegroundColor Green
Write-Host '=========================================================' -ForegroundColor Green
Write-Host "  Profil : $Profil"
Write-Host "  Cible  : $Cle"
Write-Host "`n  Reste a verifier sur un AUTRE poste (M5 du brief) :"
Write-Host '    - le double-clic suffit ;'
Write-Host '    - aucun telechargement ;'
Write-Host "    - apres retrait, rien de neuf sur le poste hote.`n"
