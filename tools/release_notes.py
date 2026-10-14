#!/usr/bin/env python3
"""Write the GitHub release text for VERSION to stdout.

A short download/install header followed by that version's section of
CHANGELOG.md. Used by the release step in .github/workflows/build.yml.
"""
import pathlib
import re

REPO = pathlib.Path(__file__).resolve().parent.parent


def main():
    version = (REPO / "VERSION").read_text(encoding="utf-8").strip()
    changelog = (REPO / "CHANGELOG.md").read_text(encoding="utf-8")
    match = re.search(rf"^## {re.escape(version)}\n(.*?)(?=^## |\Z)", changelog, re.M | re.S)
    if not match:
        raise SystemExit(f"CHANGELOG.md has no section for {version}")
    print(f"""## Instalação

1. Baixe **GTNH-Gentle-Atmosphere-{version}.zip** abaixo, em *Assets*.
2. Coloque o ZIP, **sem descompactar**, na pasta `shaderpacks` da instância.
3. No jogo: **Opções → Configurações de vídeo → Shader Packs** e selecione o pack.

Requer GT New Horizons 2.9.x com Angelica 2.2.28 ou mais nova.
*English: drop the zip (still zipped) into `.minecraft/shaderpacks` and select it under Video Settings → Shader Packs.*

## Novidades
{match.group(1).rstrip()}

---
Criado por **[CptBomba](https://github.com/CptBomba)** (Capitão Bomba) · Licença GPL-3.0
""")


if __name__ == "__main__":
    main()
