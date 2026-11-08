# Install & permissions guide — build and versioning

Source: [docs/install-and-permissions-guide.ar.md](../../docs/install-and-permissions-guide.ar.md) — Arabic part first, then `<!-- lang:en -->`, then the English part.
Output: `docs/install-and-permissions-guide.ar.pdf` and `docs/install-and-permissions-guide.en.pdf`.

## Build the PDFs

Needs Node and Chrome (or Edge — set `CHROME=...`). From the repo root:

```bash
bash tool/install_guide/build.sh
```

The current version is read from the **last row** of each part's *Change Record* table and printed in every page footer. The build fails if the Arabic and English parts disagree.

## Release a new version of the guide

1. Edit the text in **both** parts of the Markdown file.
2. Add a row at the bottom of **both** Change Record tables:
   `| DD/MM/YYYY | Vx.yy | Author | Change | Reference |` (use `—` when there is no reference).
   - **Minor** (`V1.00 → V1.01`): wording fixes, replaced screenshots.
   - **Major** (`V1.xx → V2.00`): the install/permission flow changed (a step added, removed or reordered), usually with a new app version — mention the app version in the Change column.
3. Run `build.sh` and commit the Markdown, images and both PDFs together.

## Screenshots

Raw screenshots are numbered `1.jpeg … 23.jpeg`. `prep-images.ps1` copies them to `docs/images/install-guide/NN.jpg`, cropping away private content (chats, app lists) and masking the username on image 9. Re-run it after replacing a screenshot, then rebuild:

```powershell
powershell -File tool/install_guide/prep-images.ps1 -Src <folder with 1.jpeg…> -Dst docs/images/install-guide
```

The crop rectangles in the script assume the original 738×1599 screenshots; check a replaced image after running it.
