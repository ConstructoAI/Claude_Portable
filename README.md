# Claude Portable

**Claude Code sur une clé USB, avec [Gestionnaire IA](https://github.com/ConstructoAI/Gestionnaire-IA)
embarqué. On branche, on double-clique, la session démarre — rien ne s'installe sur le poste
hôte, rien ne se télécharge au lancement.**

> ### Une gracieuseté de **Sylvain Leduc**, président de **Constructo AI inc.**
> *Écosystème intelligent pour la construction au Québec* ·
> [www.constructoai.ca](https://www.constructoai.ca)

---

## Ce que c'est

Une clé fabriquée une fois sur un poste connecté, puis autonome. Elle porte :

| Sur la clé | Rôle |
|---|---|
| `claude\claude.exe` | le moteur — binaire natif autonome, 217 Mo |
| `python\` | Python embeddable, sans installation |
| `git\` | GitPortable — Claude Code exige Git Bash sous Windows |
| `.claude\` | la couche métier : hub, scripts, skills, agents, hooks |
| `data\` | l'état d'exécution, **jetable** — voir le nettoyage |

### Ce que ce n'est pas

- Ce n'est pas [OpenClaude-Portable](https://github.com/ConstructoAI/OpenClaude-Portable),
  qui évite délibérément Claude Code au profit d'un moteur multi-fournisseurs sans abonnement.
- Ce n'est pas Gestionnaire IA, qui s'installe sur le poste via winget et npm.

C'est un troisième objet, qui emprunte la portabilité du premier et le contenu du second.
**Il exige un abonnement Claude payant.**

---

## Ce dépôt ne contient aucun binaire

Ni `claude.exe`, ni Python, ni Git, ni `pywin32` : plusieurs centaines de Mo qui n'ont
rien à faire dans git. Le dépôt porte
le **script qui fabrique** la clé. Les binaires sont récupérés à la fabrication, une seule fois,
sur votre poste.

---

## Fabriquer une clé

Sur un poste où Claude Code est déjà installé et connecté :

```
Lancer_Fabrication.bat        (double-clic — il enchaîne tout)
```

Ou en ligne de commande, pour choisir la cible et le profil :

```powershell
powershell -ExecutionPolicy Bypass -File .\Fabriquer_Cle.ps1 `
  -Cle E:\ -Profil personnelle -SourceGestionnaire C:\chemin\vers\Gestionnaire-IA
```

Le script télécharge **quatre** choses — Python embeddable, GitPortable, le wheel `pywin32`
(résolu sur l'index PyPI, l'ABI étant dérivée de la version de Python demandée) — copie
`claude.exe` et la couche `.claude\`, puis copie le lanceur.

Il **vérifie ensuite son propre travail, par exécution et non par présence** : `claude.exe`
copié répond-il ? `python.exe` s'exécute-t-il ? `import win32com.client` passe-t-il, et la DLL
résolue est-elle bien **sur la clé** ? `ost_reader.py --help` répond-il ? Il ne dit « CLÉ PRÊTE »
qu'après l'avoir constaté, et il liste chaque échec au lieu de s'arrêter au premier.

> ⚠️ Les quatre domaines à autoriser sur un réseau filtré : **python.org**, **github.com**,
> **pypi.org**, **files.pythonhosted.org**. Un blocage sur l'un d'eux est nommé dans le message
> d'erreur.

> 💡 Fabriquez d'abord dans un dossier local (`-Cle C:\test_cle`), puis copiez sur la clé.
> Sur USB 2.0, chaque essai raté coûte dix minutes ; sur le disque interne, quelques secondes.

---

## 🔴 Deux profils, et pourquoi ils ne sont pas le même objet

| | `-Profil personnelle` | `-Profil demonstration` |
|---|---|---|
| Mémoire `ETAT_*` / `JOURNAL` | complète | **vierge** |
| Profil de prix (`profiles/`) | présent | **absent** |
| Permissions | `bypassPermissions` | `default` |
| `pywin32` | installé | **absent** |
| Mode au lancement | complet (MAPI) | **inventaire** (`ost_reader`) |

`ETAT_projets.md` porte l'état de vos clients et le *pourquoi* de vos décisions.
`ENTREPRENEUR_GENERAL_QC_profil.txt` porte vos coefficients cost-plus, vos taux CCQ et vos
charges patronales — **votre structure de marge, en clair**.

Brancher une clé personnelle chez un client, c'est la lui déposer sur le bureau. Le script
**refuse de fabriquer** une clé de démonstration dont un `ETAT_*` ne serait pas vierge.

---

## Deux modes, choisis par mesure

Le lanceur ne déduit pas le mode, il le **tente** — la version Microsoft Store d'Outlook est
présente et n'expose pas MAPI/COM : chercher un `.exe` répondrait « oui » pour une installation
inutilisable.

**Mode complet** — l'objet COM `Outlook.Application` s'instancie **et** `pywin32` s'importe.
→ courriels, calendrier, dossiers, comptabilité.

**Mode inventaire** — l'un des deux manque.
→ `ost_reader.py` + `factures.py`, en lecture seule. L'agent localise le `.ost` du poste et en
sort l'arborescence et l'inventaire des messages — **jamais le corps, jamais l'envoi**.

Le mode retenu est **affiché** à chaque lancement. Un mode silencieux est un faux zéro en
puissance.

---

## 🔴 La clé personnelle est un trousseau

Mesuré le 2026-08-30, après une seule session : la redirection d'environnement fonctionne trop
bien. **Tout ce que la session lance hérite de l'environnement redirigé**, y compris le
navigateur ouvert pour la connexion. Se sont écrits sur la clé :

- `data\claude\.credentials.json` — le jeton Claude ;
- `data\home\...\Microsoft\OneAuth\` — des blobs d'identité Microsoft 365 ;
- `data\local_app_data\Google\Chrome\User Data\` — un profil Chrome complet, avec ses cookies ;
- les journaux MCP de l'ERP.

Conséquences, non négociables :

1. **Une clé personnelle se chiffre** (BitLocker To Go) et ne se prête pas.
2. **Une clé de démonstration part avec `data\` vide.** `Nettoyer_Cle.bat` s'en charge.
3. **Tant qu'une fenêtre Chrome issue d'une session est ouverte, la clé ne s'éjecte pas** — le
   profil sur la clé reste verrouillé. Le nettoyage propose de fermer Chrome et réessaie.

---

## Nettoyer avant de confier la clé

```
Nettoyer_Cle.bat              (double-clic)
```

Supprime tout `data\`. Ne touche ni à `.claude\` (la charge utile), ni au moteur. Au prochain
lancement, Claude Code redemandera une connexion.

---

## Prérequis

| | |
|---|---|
| **Abonnement Claude payant** | Pro, Max, Team, Enterprise ou Console. Le plan gratuit n'y donne pas accès |
| **Windows 10 1809+** | 64 bits |
| **Poste de fabrication** | Claude Code installé, connexion internet — une seule fois |
| **Outlook classique** | ⛔ uniquement pour le mode complet. Celui du Microsoft Store **n'expose pas MAPI/COM** |
| **Espace** | ~1 Go occupé sur la clé ; le script exige **2 Go libres** (marge d'extraction) |

---

## État des mesures

Ce dépôt suit la règle de Gestionnaire IA : **une mesure vaut mieux qu'une intuition.** Rien
n'est annoncé ici qui n'ait été constaté.

| | Mesure | État |
|---|---|---|
| M1 | `claude.exe` fonctionne hors de son dossier d'installation | ✅ `2.1.251` depuis un dossier copié |
| M2 | Python embeddable exécute `ost_reader.py` | ✅ `3.13.1`, script répond |
| M3 | `pywin32` dans le Python embeddable | ✅ **installé et vérifié par le script** — `import win32com.client` + `CoInitialize`, DLL résolue sur la clé |
| M4 | Où atterrit le jeton de connexion | ✅ **sur la clé** — d'où le nettoyage |
| M5 | La clé sur un poste qui ne l'a pas fabriquée | ⬜ non vérifié |

### 🔴 Ce que M3 a appris, et qui ne se devine pas

Poser `Lib\site-packages` dans `python313._pth` **ne suffit pas** : `pywintypes` vit dans
`win32\lib`, ajouté par le `pywin32.pth` du wheel — et un `.pth` n'est lu que si `site.main()`
s'exécute. Mesuré, même wheel, même Python :

| `python313._pth` | `import win32com.client` | `ENABLE_USER_SITE` |
|---|---|---|
| `Lib\site-packages` seul | 🔴 `ModuleNotFoundError: pywintypes` | — |
| `+ import site` | ✅ | 🔴 **`True`** |
| **chemins pywin32 explicites** | ✅ | ✅ **`None`** |

La deuxième ligne marche **et ouvre la clé au poste hôte** : `import site` réactive le
`%APPDATA%\Python\Python313\site-packages` de la machine visitée, dont un `usercustomize.py`
s'exécuterait dans l'interpréteur de la clé. C'est exactement la promesse « rien du poste hôte »
que ce projet vend. **Le script pose donc les chemins à la main** — `win32`, `win32\lib`,
`pythonwin` — et laisse `import site` commenté.

Détail complet dans [`docs/BRIEF.md`](docs/BRIEF.md).

---

## Licence

MIT — voir [LICENSE](LICENSE).

Si vous l'améliorez, les corrections **mesurées** sont les bienvenues.
