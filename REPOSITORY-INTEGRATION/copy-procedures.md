# Copy Procedures

| Field | Value |
|---|---|
| **Project** | Enterprise Systems Administration Lab (ESAL) |
| **Document** | Copy Procedures |
| **Version** | 1.0.0 |
| **Status** | DRAFT / PROPOSED |
| **Last updated** | 2026-11-22 |
| **Scope** | How to copy this package into the local clone of the repository safely |

> These procedures are **executed by the project owner**. Nothing has been copied, committed or
> pushed by Claude. The commands only **add** files or **fill empty** files; they never delete,
> rename or overwrite a file that has content.

---

## 1. Before you start

1. Extract `ESAL-DOCUMENTATION-FOUNDATION-v1.0.0.zip`.
2. Open a terminal in your local clone of the repository and confirm the state:

```bash
git status            # expect: working tree clean, branch main
git pull              # make sure you have the latest main
```

3. (Recommended) Create a branch for the integration:

```bash
git switch -c docs/documentation-foundation-v1.0.0
```

Set the package path once (adapt to where you extracted it):

```bash
# macOS / Linux
PKG="$HOME/Downloads/ESAL-DOCUMENTATION-FOUNDATION-v1.0.0"
```

```powershell
# Windows PowerShell
$PKG = "$HOME\Downloads\ESAL-DOCUMENTATION-FOUNDATION-v1.0.0"
```

## 2. Safety check — destinations must be empty or absent

Run from the repository root. Any line marked `HAS CONTENT` means **stop and merge manually**.

```bash
# macOS / Linux
cd "$PKG" && find docs infrastructure -type f | while read -r f; do
  dest="$OLDPWD/$f"
  if [ -s "$dest" ]; then echo "HAS CONTENT  $f"; elif [ -e "$dest" ]; then echo "EMPTY        $f"; else echo "ABSENT       $f"; fi
done; cd - >/dev/null
```

```powershell
# Windows PowerShell
$repo = (Get-Location).Path
Get-ChildItem -Path "$PKG\docs","$PKG\infrastructure" -Recurse -File | ForEach-Object {
    $rel  = $_.FullName.Substring($PKG.Length + 1)
    $dest = Join-Path $repo $rel
    if (Test-Path $dest) {
        if ((Get-Item $dest).Length -gt 0) { "HAS CONTENT  $rel" } else { "EMPTY        $rel" }
    } else { "ABSENT       $rel" }
}
```

Expected result based on the inspection of commit `832cc91`: 5 × `EMPTY`, 18 × `ABSENT`,
0 × `HAS CONTENT`.

## 3. Copy

Only files that are absent or empty are copied; anything else is reported and skipped.

```bash
# macOS / Linux — run from the repository root
REPO="$(pwd)"
( cd "$PKG" && find docs infrastructure -type f ) | while read -r f; do
  if [ -s "$REPO/$f" ]; then
    echo "SKIPPED (has content, merge manually): $f"
  else
    mkdir -p "$REPO/$(dirname "$f")" && cp "$PKG/$f" "$REPO/$f" && echo "copied $f"
  fi
done
```

```powershell
# Windows PowerShell — run from the repository root
$repo = (Get-Location).Path
Get-ChildItem -Path "$PKG\docs","$PKG\infrastructure" -Recurse -File | ForEach-Object {
    $rel  = $_.FullName.Substring($PKG.Length + 1)
    $dest = Join-Path $repo $rel
    if ((Test-Path $dest) -and ((Get-Item $dest).Length -gt 0)) {
        "SKIPPED (has content, merge manually): $rel"
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        Copy-Item -Path $_.FullName -Destination $dest
        "copied $rel"
    }
}
```

## 4. Review the result

```bash
git status
git diff --stat
```

Expected:

- 5 modified files (previously empty).
- 18 new files: 13 documents (including 3 with corrected names) and 5 diagram sources.
- New folders `docs/cloud/` and `infrastructure/diagrams/`.
- The 3 superseded empty files are **still present** (see [file-mapping.md](file-mapping.md#4-conflicts-and-superseded-files)).

Preview the Markdown and diagrams on GitHub (after pushing your branch) or in an editor with
Mermaid preview support.

## 5. Commit (owner's decision)

Suggested commit message (Conventional Commits):

```text
docs: add documentation foundation v1.0.0

- project brief, architecture, networking, AD, security and cloud docs
- five Mermaid diagram sources in infrastructure/diagrams
- status: DRAFT / PROPOSED, nothing deployed
```

## 6. If something goes wrong

| Situation | Action |
|---|---|
| Wrong files copied, not yet committed | `git restore .` (modified) and `git clean -n` (preview untracked) then `git clean -f` once reviewed |
| A destination had content | Merge by hand: keep both texts, reconcile, then remove duplicates |
| Committed on the wrong branch | `git reset --soft HEAD~1` and re-commit on the right branch |
