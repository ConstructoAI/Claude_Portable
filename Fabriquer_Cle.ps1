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
    [string]$GitVersion    = '2.54.0',
    [string]$Pywin32Version = '312'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

function Etape($t) { Write-Host "`n[~] $t" -ForegroundColor Yellow }
function Bon($t)   { Write-Host "    [OK] $t"  -ForegroundColor Green }
function Mal($t)   { Write-Host "    [X]  $t"  -ForegroundColor Red }
function Note($t)  { Write-Host "    $t"       -ForegroundColor DarkGray }

# Lance un executable et REND son code, sans jamais lever.
# 🔴 Mesure du 2026-08-30 : sous $ErrorActionPreference = 'Stop', un exe qui
#    ecrit sur stderr fait LEVER `& exe ... 2>&1` (NativeCommandError). Les
#    trois controles de l'etape 7 employaient ce motif : au premier echec le
#    script mourait sur une trace PowerShell brute, et la collecte de $echecs
#    - donc le rapport « FABRICATION INCOMPLETE » que ce fichier promet en
#    tete - ne s'executait JAMAIS.
#    Rediriger vers un fichier (2>f) ne suffit pas : mesure faite, ca leve
#    aussi. Il faut abaisser la preference le temps de l'appel.
#    ⚠️ ABAISSER LA PREFERENCE NE SUFFIT PAS. Mesure du 2026-08-30 : elle
#    neutralise les erreurs de FLUX, pas celles de LANCEMENT. Un exe absent leve
#    CommandNotFoundException, un exe de 0 octet leve ApplicationFailedException,
#    et les deux sont terminantes quoi qu'on mette dans la preference. Il faut
#    donc refuser AVANT d'appeler, et attraper autour.
# 🔴 Les telechargements sont hors du dispositif $echecs : sous 'Stop', une coupure
#    reseau tue le script sur une trace brute, et « FABRICATION INCOMPLETE » ne
#    s'imprime jamais. Cette fonction rend l'echec LISIBLE et nomme le domaine.
function Telecharger {
    param([string]$Url, [string]$Vers, [string]$Quoi)
    $hote = ([uri]$Url).Host
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Vers -UseBasicParsing -TimeoutSec 300
    } catch {
        throw ("Telechargement de $Quoi impossible depuis $hote.`n" +
               "    Cause : $($_.Exception.Message)`n" +
               "    Les quatre domaines a autoriser sont : python.org, github.com, " +
               "pypi.org, files.pythonhosted.org.")
    }
    if (-not (Test-Path -LiteralPath $Vers) -or (Get-Item -LiteralPath $Vers).Length -eq 0) {
        throw "Telechargement de $Quoi vide depuis $hote."
    }
    # 🔴 `Length -eq 0` NE PEUT PAS voir un portail captif : il rend ~149 octets
    #    de HTML, pas zero. Mesure du 2026-08-31 : les trois telechargements
    #    « reussissaient », puis mouraient a l'extraction sur une trace .NET
    #    (« End of Central Directory » / « fichier endommage »). C'est la lecon
    #    `curl -f` deja ecrite dans Lancer_Fabrication.bat, jamais transposee ici.
    #    On lit donc les octets de tete : PK pour un zip/whl, MZ pour le SFX.
    $tete = [System.IO.File]::ReadAllBytes($Vers)[0..1]
    $magie = [char]$tete[0] + [string][char]$tete[1]
    if ($magie -ne 'PK' -and $magie -ne 'MZ') {
        Remove-Item -LiteralPath $Vers -Force -ErrorAction SilentlyContinue
        throw ("$Quoi telecharge depuis $hote n'est ni une archive ni un executable " +
               "(entete « $magie »). C'est presque toujours un portail captif ou un " +
               "proxy qui a repondu une page web a la place du fichier.")
    }
}

function Executer {
    param([string]$Exe, [string[]]$Arguments)
    if (-not (Test-Path -LiteralPath $Exe)) {
        return [pscustomobject]@{ Code = -1; Sortie = "introuvable : $Exe" }
    }
    if ((Get-Item -LiteralPath $Exe).Length -eq 0) {
        return [pscustomobject]@{ Code = -1; Sortie = "fichier vide : $Exe" }
    }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    # 🔴 $LASTEXITCODE est GLOBAL et REMANENT : s'il n'est pas remis a zero, un
    #    appel qui ne demarre pas rend le code du PRECEDENT exe - donc 0, donc un
    #    « [OK] » vert portant un message d'erreur.
    $global:LASTEXITCODE = $null
    try {
        $sortie = & $Exe @Arguments 2>&1
        $code = if ($null -eq $LASTEXITCODE) { -1 } else { $LASTEXITCODE }
        # 🔴 Ne PAS rendre l'ErrorRecord entier : son rendu contient la ligne de
        #    source, les tildes et FullyQualifiedErrorId. Ca deplacerait la trace
        #    PowerShell du terminal vers $echecs au lieu de la supprimer.
        $texte = ($sortie | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message }
            else { $_ }
        } | Out-String).Trim()
        return [pscustomobject]@{ Code = $code; Sortie = $texte }
    } catch {
        # 🔴 .Exception.Message NE SUFFIT PAS. Pour ApplicationFailedException --
        #    exe corrompu, PE tronque, page HTML sauvee en .exe -- ce Message
        #    CONTIENT DEJA la trace : « Au caractere ...:16 : 19 », la ligne
        #    source et les tildes. Le filtre pose plus haut nettoyait le flux de
        #    SORTIE ; la trace revenait par ici, et se retrouvait recopiee dans
        #    $echecs, donc dans le rapport destine a Sylvain. Mesure : trois
        #    copies, une par controle. On coupe donc a la premiere ligne utile.
        $m = "$($_.Exception.Message)"
        $i = $m.IndexOf("`nAu caract")
        if ($i -lt 0) { $i = $m.IndexOf("`nAt line:") }
        if ($i -gt 0) { $m = $m.Substring(0, $i) }
        return [pscustomobject]@{ Code = -1; Sortie = $m.Trim() }
    } finally { $ErrorActionPreference = $prev }
}

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

# 🔴 $dTravail n'est nettoye qu'a la toute fin : tout `throw` en amont laisse
#    jusqu'a 73 Mo dans %TEMP%, sous un nom neuf a chaque essai. Trois essais
#    rates sur un reseau capricieux = ~220 Mo abandonnes sur un poste dont ce
#    script promet qu'il ne laisse rien. On balaie donc les restes AVANT.
Get-ChildItem -LiteralPath $env:TEMP -Directory -Filter 'cle_gia_*' -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddHours(-1) } |
    ForEach-Object {
        try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop }
        catch { }
    }
$dTravail = Join-Path $env:TEMP ("cle_gia_" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $dTravail | Out-Null

# ---------------------------------------------------- 1. Le profil metier
# 🔴 Verrou de confidentialite. Une cle de demonstration ne doit porter
#    NI la memoire accumulee (etat client, decisions, engagements),
#    NI le profil de prix (coefficients cost-plus, taux CCQ).
#    Le script REFUSE de fabriquer plutot que de laisser passer.
Etape 'Controle du contenu selon le profil'

# 🔴 JOURNAL.md EN FAIT PARTIE, et il manquait. Le README et le BRIEF promettent
#    tous deux « Memoire ETAT_* / JOURNAL : vierge » sur une cle de demonstration,
#    et le BRIEF precise lui-meme que ce fichier « arrive NON vide » : 714 lignes
#    de l'histoire du poste -- decisions, mesures, ce qu'elles ont coute -- qui
#    partaient chez le client sous une case disant « vierge ».
$fichiersMemoire = @(
    'ETAT_projets.md', 'ETAT_calendrier.md',
    'ETAT_courriels_poste.md', 'ETAT_comptabilite.md',
    'JOURNAL.md'
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
$zipPy = Join-Path $dTravail 'python-embed.zip'
$urlPy = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-amd64.zip"
Note $urlPy
Telecharger $urlPy $zipPy 'Python embeddable'
# 🔴 SUPPRIMER SEULEMENT UNE FOIS L'ARCHIVE EN MAIN. L'ancien ordre effacait
#    python\ AVANT le telechargement : une coupure reseau laissait alors la cle
#    PIRE qu'avant -- on relance une fabrication sur une cle qui marchait, et on
#    repart avec un dossier en moins. Meme correction pour git\ plus bas.
if (Test-Path -LiteralPath $dstPy) { Remove-Item -LiteralPath $dstPy -Recurse -Force }
Expand-Archive -LiteralPath $zipPy -DestinationPath $dstPy -Force
Bon 'extrait'

if ($Profil -eq 'personnelle') {
    # ---------------------------------------------------- 3-bis. pywin32
    # Sans lui le lanceur reste en mode inventaire : pas de MAPI, donc ni
    # courriels ni calendrier.
    #
    # 🔴 DEUX LIGNES SONT NECESSAIRES DANS LE _pth, PAS UNE. Mesure du
    #    2026-08-30 sur Python 3.13.1 embeddable + pywin32 312 :
    #
    #      'Lib\site-packages' seul   -> ModuleNotFoundError: pywintypes
    #      + 'import site'            -> import win32com.client OK
    #
    #    'pywintypes' vit dans 'win32\lib', ajoute par le pywin32.pth du
    #    wheel - et un .pth n'est LU que si site.main() s'execute. C'est
    #    aussi ce qui charge pywin32_bootstrap, donc les DLL de
    #    pywin32_system32. Sans 'import site', rien ne les trouve, et il
    #    est inutile de les recopier a la main : mesure faite, le bootstrap
    #    resout pythoncom313.dll depuis site-packages tout seul.
    #
    #    L'ancienne version de ce bloc posait 'Lib\site-packages' puis
    #    disait « deposez-y le wheel ». Suivie a la lettre, elle ne
    #    fonctionnait PAS - c'est l'essai qui echoue ci-dessus.
    Etape "pywin32 $Pywin32Version (mode complet uniquement)"

    # Le tag ABI SUIT la version de Python demandee : un wheel cp313 sur un
    # Python 3.12 ne s'importe pas.
    $vp = $PythonVersion -split '\.'
    if ($vp.Count -lt 2) { throw "PythonVersion illisible : $PythonVersion" }
    $abi = "cp$($vp[0])$($vp[1])"
    Note "ABI cible : $abi (derive de Python $PythonVersion)"

    # L'URL de files.pythonhosted.org porte un repertoire de HACHAGE : elle
    # ne se construit pas a la main, il faut la demander a l'index.
    # 🔴 SEUL TELECHARGEMENT HORS DE `Telecharger`, et le pire a laisser nu.
    #    Mesure du 2026-08-31 contre un serveur rendant 200 + HTML (portail
    #    captif, proxy) : Invoke-RestMethod rend un XmlDocument ou une String,
    #    $meta.urls vaut $null, et le message final accuse LE WHEEL avec une
    #    liste de disponibles VIDE. Sylvain irait chercher une mauvaise version
    #    de pywin32 pendant que la cause est le reseau. Et le chemin double-clic
    #    traverse toujours cette ligne.
    try {
        $meta = Invoke-RestMethod -Uri "https://pypi.org/pypi/pywin32/$Pywin32Version/json" -UseBasicParsing -TimeoutSec 60
    } catch {
        throw ("Interrogation de l'index PyPI impossible (pypi.org).`n" +
               "    Cause : $($_.Exception.Message)`n" +
               "    Les quatre domaines a autoriser sont : python.org, github.com, " +
               "pypi.org, files.pythonhosted.org.")
    }
    if ($meta -isnot [pscustomobject] -or -not $meta.urls) {
        throw ("pypi.org a repondu autre chose que la fiche attendue (portail captif ou proxy ?).`n" +
               "    Ce n'est PAS un probleme de version de pywin32.")
    }
    $attendu = "pywin32-$Pywin32Version-$abi-$abi-win_amd64.whl"
    $info = $meta.urls | Where-Object { $_.filename -eq $attendu } | Select-Object -First 1
    if (-not $info) {
        $dispo = ($meta.urls | Where-Object { $_.filename -match 'win_amd64\.whl$' } |
                  ForEach-Object { $_.filename }) -join ', '
        throw "Wheel introuvable : $attendu. Disponibles pour pywin32 $Pywin32Version : $dispo"
    }
    Note $info.url

    # Un .whl EST un zip, mais Expand-Archive refuse l'extension inconnue.
    $whl = Join-Path $dTravail 'pywin32.zip'
    Telecharger $info.url $whl 'le wheel pywin32'
    $sp = Join-Path $dstPy 'Lib\site-packages'
    New-Item -ItemType Directory -Force -Path $sp | Out-Null
    Expand-Archive -LiteralPath $whl -DestinationPath $sp -Force
    Bon "$($info.filename) extrait"

    # 🔴 PAS `import site` : il OUVRE LA CLE AU POSTE HOTE. Mesure du 2026-08-30 :
    #    avec `import site`, ENABLE_USER_SITE devient True et le
    #    %APPDATA%\Python\Python313\site-packages de la machine visitee entre dans
    #    sys.path - un `pip install --user` de l'hote, et meme son usercustomize.py,
    #    s'executent dans l'interpreteur de la CLE. C'est exactement la promesse
    #    « rien du poste hote » que ce projet vend.
    #    Les chemins que `pywin32.pth` aurait ajoutes sont donc poses A LA MAIN.
    #    Mesure comparative, meme wheel, meme Python :
    #      import site + Lib\site-packages   -> import OK, ENABLE_USER_SITE = True
    #      chemins explicites (ci-dessous)   -> import OK, ENABLE_USER_SITE = None
    #    Les deux resolvent pythoncom313.dll DANS la cle. Le second n'ouvre rien.
    $pth = Get-ChildItem -LiteralPath $dstPy -Filter 'python*._pth' | Select-Object -First 1
    if (-not $pth) { throw "Aucun python*._pth dans $dstPy : site-packages restera inactif." }
    # ⚠️ Les parentheses autour du pipe sont NECESSAIRES : sans elles, un fichier
    #    d'une seule ligne rend une String et le `+=` suivant CONCATENE au lieu
    #    d'ajouter une ligne - le _pth serait detruit en silence.
    $lignes = @(Get-Content -LiteralPath $pth.FullName)
    foreach ($ajout in @(
        'Lib\site-packages',
        'Lib\site-packages\win32',
        'Lib\site-packages\win32\lib',
        'Lib\site-packages\pythonwin'
    )) {
        if ($lignes -notcontains $ajout) { $lignes += $ajout }
    }
    Set-Content -LiteralPath $pth.FullName -Value $lignes -Encoding ASCII
    Bon "$($pth.Name) : chemins pywin32 explicites (sans import site)"

    # 🔴 LES QUATRE CHEMINS NE SUFFISENT PAS. Mesure du 2026-08-31, processus neuf
    #    par import, 24 modules pywin32 :
    #
    #      4 chemins seuls            ->  4 / 24   (win32api, win32file, win32gui,
    #                                     win32security... echouent en DLL load failed)
    #      + import site              -> 23 / 24   mais ENABLE_USER_SITE = True
    #      + les DLL ici              -> 23 / 24   et ENABLE_USER_SITE = None
    #
    #    Pourquoi : `pywin32.pth` porte QUATRE lignes actives, pas trois. La
    #    quatrieme, `import pywin32_bootstrap`, est EXECUTABLE -- c'est elle qui
    #    appelle os.add_dll_directory(). On ne peut pas la recopier : un ._pth
    #    n'accepte que `import site`, tout autre import est ignore avec
    #    « unsupported 'import' line » sur stderr (mesure faite).
    #    Sans elle, seul `pywintypes.py` (chercheur en Python pur) charge la DLL,
    #    et uniquement si un module l'importe d'abord : `import win32com.client`
    #    marche, `import win32api` non. C'est le defaut que le code amont de
    #    pywin32 documente mot pour mot.
    #
    #    ⚠️ ET CA FERME UN AUTRE TROU : _win32sysloader demande la DLL par NOM NU,
    #    et System32 est dans l'ordre de recherche. Sur un poste ou pywin32 est
    #    installe pour le meme Python, la cle pouvait lier la DLL de l'HOTE. Le
    #    repertoire de l'application precede System32 : la copie tranche.
    #    C'est ce que fait le post-install officiel de pywin32 en non-admin.
    $sys32 = Join-Path $sp 'pywin32_system32'
    if (Test-Path -LiteralPath $sys32) {
        $dlls = @(Get-ChildItem -LiteralPath $sys32 -Filter '*.dll' -ErrorAction SilentlyContinue)
        foreach ($d in $dlls) { Copy-Item -LiteralPath $d.FullName -Destination $dstPy -Force }
        if ($dlls.Count -eq 0) { throw "pywin32_system32 ne contient aucune DLL : le wheel est incomplet." }
        Bon "$($dlls.Count) DLL pywin32 posees a cote de python.exe"
    } else {
        throw "pywin32_system32 absent de $sp : le wheel n'a pas ete extrait correctement."
    }
}

# ------------------------------------------------------------ 4. GitPortable
Etape "GitPortable $GitVersion"
$dstGit = Join-Path $Cle 'git'
$exeGit = Join-Path $dTravail 'GitPortable.exe'
$urlGit = "https://github.com/git-for-windows/git/releases/download/v$GitVersion.windows.1/PortableGit-$GitVersion-64-bit.7z.exe"
Note $urlGit
Telecharger $urlGit $exeGit 'GitPortable'
# Meme raison qu'a l'etape 3 : on n'efface qu'une fois l'archive en main.
if (Test-Path -LiteralPath $dstGit) { Remove-Item -LiteralPath $dstGit -Recurse -Force }
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
# 🔴 ET LE NETTOYEUR AVEC. Il n'etait PAS copie : le README documentait un
#    double-clic sur un fichier absent de la cle. C'est l'outil qui efface le
#    jeton Claude, les blobs d'identite Microsoft et le profil Chrome -- la cle
#    les emporte, le moyen de les effacer restait sur le poste de fabrication.
#    Et comme il fait `set "CLE=%~dp0"`, il ne nettoie QUE s'il est a la racine
#    de la cle : le copier ailleurs ne servirait a rien.
$srcNet = Join-Path $PSScriptRoot 'Nettoyer_Cle.bat'
if (-not (Test-Path -LiteralPath $srcNet)) { throw "Nettoyer_Cle.bat introuvable a cote de ce script." }
Copy-Item -LiteralPath $srcNet -Destination $Cle -Force
Bon 'copie'

# --------------------------------------------- 7. Verification du travail
# Le script ne dit « termine » qu'apres avoir constate, pas suppose.
Etape 'Verification'
$echecs = @()

# ⚠️ ost_reader.py et factures.py sont TOUT le mode inventaire -- le seul mode
#    d'une cle de demonstration. Le controle d'execution d'ost_reader etait
#    enveloppe d'un `if (Test-Path)` : absent, il ne s'executait pas, aucun echec
#    n'etait collecte, et la cle etait declaree prete. Un faux zero par
#    construction. Ils sont donc exiges ici.
$attendus = @(
    'claude\claude.exe', 'python\python.exe',
    'git\bin\bash.exe', '.claude\CLAUDE.md', 'Constructo_AI.bat',
    'Nettoyer_Cle.bat',
    '.claude\scripts\ost_reader.py', '.claude\scripts\factures.py'
)
foreach ($rel in $attendus) {
    $p = Join-Path $Cle $rel
    if (-not (Test-Path -LiteralPath $p)) { $echecs += "absent : $rel"; continue }
    if ((Get-Item -LiteralPath $p).Length -eq 0) { $echecs += "vide : $rel" }
}

# Les controles qui suivent FONT EXECUTER le binaire ; ils ne constatent pas sa
# presence. Tous passent par Executer : un echec est COLLECTE, il n'interrompt plus.
# ⚠️ `git\bin\bash.exe` fait exception : il n'est que constate ci-dessus.
#
# 🔴 Si la boucle ci-dessus a deja declare un fichier absent ou vide, on NE
#    l'execute pas. Sans ce garde, le script ecrivait l'echec dans $echecs puis
#    allait lancer le fichier manquant - et mourait avant d'avoir imprime quoi que
#    ce soit. Cas le plus courant : `claude` du PATH est un shim npm .cmd sans
#    claude.exe a cote, donc le dossier copie n'en contient pas.
$manquants = @($echecs)

# claude.exe relocalise repond-il ? (mesure M1 du brief, faite ici)
$r = if ($manquants -match 'claude\\claude\.exe') {
    [pscustomobject]@{ Code = -1; Sortie = 'non execute : deja signale absent ou vide' }
} else { Executer (Join-Path $Cle 'claude\claude.exe') @('--version') }
if ($r.Code -ne 0 -or [string]::IsNullOrWhiteSpace($r.Sortie)) {
    $echecs += "claude.exe copie ne repond pas. Sortie : $($r.Sortie)"
} else {
    Bon "claude.exe : $($r.Sortie)"
    $vClaudeVersion = $r.Sortie
}

$pyExe = Join-Path $Cle 'python\python.exe'

# Python : le faire EXECUTER, pas constater sa presence.
$pyManquant = [bool]($manquants -match 'python\\python\.exe')
$r = if ($pyManquant) {
    [pscustomobject]@{ Code = -1; Sortie = 'non execute : deja signale absent ou vide' }
} else { Executer $pyExe @('-c', 'import sys; print(sys.version.split()[0])') }
if ($r.Code -ne 0 -or [string]::IsNullOrWhiteSpace($r.Sortie)) {
    $echecs += "python.exe ne s'execute pas. Sortie : $($r.Sortie)"
} else {
    Bon "python.exe : $($r.Sortie)"
}

# pywin32 : mesure M3 du brief, faite ICI et non renvoyee a plus tard.
# Le seul controle qui vaille est l'IMPORT : le dossier peut etre complet
# et l'import echouer (cf. le commentaire de l'etape 3-bis).
if ($Profil -eq 'personnelle') {
    $r = Executer $pyExe @('-c', 'import win32com.client, pythoncom; pythoncom.CoInitialize(); pythoncom.CoUninitialize(); print(pythoncom.__file__)')
    if ($r.Code -ne 0) {
        $echecs += "pywin32 : import win32com.client a echoue - le lanceur restera en mode inventaire (ni courriels ni calendrier). Sortie : $($r.Sortie)"
    } elseif ($r.Sortie -and -not $r.Sortie.StartsWith($Cle, [StringComparison]::OrdinalIgnoreCase)) {
        # 🔴 Un vert obtenu grace au pywin32 du POSTE DE FABRICATION ne dit rien de
        #    la cle. Le controle imprimait pythoncom.__file__ sans jamais le
        #    comparer a la cible : un humain POUVAIT le voir, rien ne le verifiait.
        $echecs += "pywin32 resolu HORS de la cle : $($r.Sortie). La cle ne serait pas autonome."
    } else {
        Bon 'pywin32 : import win32com.client + CoInitialize'
        Note $r.Sortie
    }
}

# ost_reader : bibliotheque standard seulement, doit repondre partout.
$ost = Join-Path $Cle '.claude\scripts\ost_reader.py'
if (Test-Path -LiteralPath $ost) {
    $r = Executer $pyExe @($ost, '--help')
    if ($r.Code -ne 0) {
        $echecs += "ost_reader.py --help a echoue. Sortie : $($r.Sortie)"
    } else {
        Bon 'ost_reader.py repond'
    }
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

# 🔴 UN MARQUEUR, parce que rien sur la cle ne disait si elle etait finie. Une
#    cle complete et une cle abandonnee en cours de route etaient indiscernables
#    dans l'explorateur. Ecrit EN DERNIER, apres que tous les controles sont
#    passes : sa presence est la seule preuve qu'ils l'ont ete.
$marqueur = Join-Path $Cle 'CLE_PRETE.txt'
@(
    "Cle Claude Portable - fabriquee le $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    "Profil        : $Profil"
    "Claude Code   : $($vClaudeVersion)"
    "Python        : $PythonVersion"
    "GitPortable   : $GitVersion"
    "pywin32       : $(if ($Profil -eq 'personnelle') { $Pywin32Version } else { 'absent (profil demonstration)' })"
    ""
    "Ce fichier n'est ecrit QUE si tous les controles de fabrication sont passes."
    "S'il manque, la cle est incomplete : ne la distribuez pas."
) | Set-Content -LiteralPath $marqueur -Encoding UTF8

Write-Host '=========================================================' -ForegroundColor Green
Write-Host '  CLE PRETE' -ForegroundColor Green
Write-Host '=========================================================' -ForegroundColor Green
Write-Host "  Profil : $Profil"
Write-Host "  Cible  : $Cle"
Write-Host "`n  Reste a verifier sur un AUTRE poste (M5 du brief) :"
Write-Host '    - le double-clic suffit ;'
Write-Host '    - aucun telechargement ;'
Write-Host "    - apres retrait, rien de neuf sur le poste hote.`n"
