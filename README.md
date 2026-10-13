# GTNH Gentle Atmosphere

Shaderpack leve para **GregTech: New Horizons 2.9** (Minecraft 1.7.10 + Angelica).
A ideia é simples: deixar o mundo mais bonito e com mais vida **sem mudar a cara do
jogo** e sem pesar como os shaders "realistas". As texturas, as cores dos biomas, a
luz das tochas e as máquinas continuam como você conhece. O que muda é a atmosfera.

> *English summary at the end of this page.*

## O que ele faz

- **Céu e nuvens:** gradiente de céu suave que acompanha a hora do dia e a chuva.
  Nuvens próprias em blocos chanfrados, no estilo do Minecraft, com variação de
  formato, movimento lento e brilho quente perto do sol no nascer e no pôr do sol.
  Na chuva elas ficam acinzentadas.
- **Sol e sombras:** sombras projetadas suaves (mapa 2048, até 64 blocos) do
  terreno, da vegetação, do jogador, de mobs e de blocos especiais. As sombras
  têm tom azulado de céu, nunca preto. Interiores, cavernas e bases ficam livres
  de vazamento de luz.
- **Água:** ondas contínuas, reflexo do céu e do cenário visível, brilho do sol
  e noção de profundidade: margens rasas mais transparentes, água funda mais
  densa e azul.
- **Vegetação viva:** grama, flores, plantações e folhas balançam com o vento,
  com a base da planta presa ao chão e o movimento diminuindo à distância.
- **Imagem:** FXAA, nitidez adaptativa sem halos, bloom discreto e compressão
  dos tons muito claros.
- **Seguro para o modpack:** Nether, End e dimensões de mods (Galacticraft,
  GalaxySpace etc.) ficam com a renderização original. Máquinas, cabos, fluidos
  de mods e blocos desconhecidos não são deformados nem recoloridos.

## Requisitos

| | |
|---|---|
| Modpack | GT New Horizons 2.9.x (desenvolvido na 2.9.0-RC-2) |
| Renderizador | Angelica 2.2.28 ou mais nova, com shaders habilitados |
| Placa de vídeo | Qualquer GPU com OpenGL 2.1 / GLSL 1.20. O perfil Minimal roda em máquinas modestas |

O shader é só do cliente: não exige nada do servidor e não altera mundo, receitas
ou progressão.

## Instalação

1. Baixe o arquivo `GTNH-Gentle-Atmosphere-x.y.z.zip` na página de
   [Releases](https://github.com/CptBomba/Shader-GTNH-Gentle-Atomosphere/releases).
2. Coloque o ZIP, **sem descompactar**, na pasta `shaderpacks` da instância
   (ex.: `.minecraft/shaderpacks/`).
3. No jogo: **Opções → Configurações de vídeo → Shader Packs** e selecione
   *GTNH-Gentle-Atmosphere*.
4. Em **Shader Options** escolha um perfil. O padrão é **Natural**.

Para atualizar, troque o ZIP antigo pelo novo. Suas opções ficam guardadas no
arquivo `.txt` com o mesmo nome do pack na pasta `shaderpacks`.

## Perfis

| Perfil | Para quem | Sombras | Nuvens | Água |
|---|---|---|---|---|
| **Minimal** | PCs modestos, bases enormes | Desligadas (só sombreamento direcional) | Simples | Original do jogo |
| **Natural** *(padrão)* | Equilíbrio entre beleza e FPS | Suaves, 64 blocos | Formações variadas | Ondas, reflexos (12 passos), profundidade |
| **Atmospheric** | Capturas de tela, PCs folgados | Mais suaves | Duas camadas | Reflexos detalhados (24 passos) |

Todas as opções podem ser ajustadas individualmente nos submenus *Nuvens*,
*Vegetação*, *Luz e sombras*, *Água e reflexos*, *Nitidez e brilho* e
*Compatibilidade*. Os menus estão em português e inglês.

### Dicas de desempenho

- **Sombras** são a opção mais cara. Desligá-las (ou usar Minimal) é o maior
  ganho de FPS. Em ambientes internos e subterrâneos o shader já pula o cálculo
  de sombra automaticamente.
- **Qualidade das nuvens** em *Simples* reduz o custo do céu.
- **Reflexos da cena** em *Céu aproximado* remove o traçado de raios na água.

## Perguntas frequentes

**Um rio/lago aparece preto.** Provavelmente é um fluido de mod, como petróleo.
O shader mantém a cor original de qualquer fluido que não seja a água vanilla.
Se o minimapa também mostra o local preto, o bloco realmente é escuro.

**As nuvens sumiram / quero as nuvens do Minecraft.** Em *Nuvens → Formação das
nuvens* escolha *Nativo*. *Qualidade das nuvens → Desligadas* esconde as nuvens.

**Estou numa dimensão de mod e o céu ficou estranho.** O shader identifica a
Superfície pelo bioma. Se alguma dimensão reutiliza biomas da Superfície, desligue
*Compatibilidade → Atmosfera terrestre*.

**Reflexos somem na borda da tela.** É uma limitação dos reflexos em tela (SSR):
só aparece o que está visível. Fora da tela, a água reflete o céu.

## Limitações conhecidas

- Plantas duplas (girassol, grama alta dupla), trepadeiras e plantas de mods não
  mapeadas ficam paradas, para evitar deformar blocos que não são plantas.
- Sombras projetadas alcançam 64 blocos; depois disso o terreno fica iluminado
  por igual.
- *Sombras de luzes locais* é uma opção experimental que depende de um mod
  complementar (Gentle Lights) que ainda não é distribuído. Sem ele a opção não
  faz nada; ela vem desligada.
- Não há DLSS, ray tracing ou path tracing. FXAA e nitidez são filtros espaciais.

## Para desenvolvedores

```
shaders/
  shaders.properties   perfis, menus e configuração do Angelica
  block.properties     IDs de material (folhas, plantas, plantações, água)
  lang/                textos dos menus (en_US, pt_BR)
  lib/                 código compartilhado (luz, sombras, água, céu, nuvens...)
  program/             implementação dos passes
  *.fsh / *.vsh        pontos de entrada da Superfície
  world-1/, world1/    pontos de entrada do Nether e do End (renderização nativa)
tools/
  validate.py          compila todos os programas com todos os perfis
  build.py             gera dist/GTNH-Gentle-Atmosphere-<versão>.zip
docs/TECNICO.md        notas técnicas do pipeline
```

```sh
sudo apt install glslang-tools   # glslangValidator
python3 tools/validate.py        # 138 programas x 6 conjuntos de opções
python3 tools/build.py           # empacota o ZIP
```

O GitHub Actions roda a validação e gera o ZIP em cada push. Para publicar uma
versão, atualize `VERSION` e `CHANGELOG.md` e crie uma tag `vX.Y.Z`: o ZIP é
anexado automaticamente à Release.

Relatos de problemas são bem-vindos nas
[Issues](https://github.com/CptBomba/Shader-GTNH-Gentle-Atomosphere/issues).
Inclua uma captura de tela, o perfil usado, a versão do GTNH/Angelica e sua placa
de vídeo.

## Licença

[GPL-3.0](LICENSE). Você pode usar, modificar e redistribuir, mantendo a mesma
licença e os créditos.

---

## English summary

**GTNH Gentle Atmosphere** is a lightweight shaderpack for **GT New Horizons 2.9**
(Minecraft 1.7.10 + Angelica 2.2.28+). It makes the world prettier and more alive
while keeping the vanilla look: soft sky gradient, blocky bevelled clouds that glow
near the sun, soft sky-tinted sun shadows with no indoor light leaks, waving water
with screen-space reflections and depth (clear shores, deeper water), wind on
grass, flowers, crops and leaves, plus FXAA, adaptive sharpening and subtle bloom.
Nether, End and modded dimensions keep native rendering; machines, cables and mod
fluids are never altered.

**Install:** download the zip from
[Releases](https://github.com/CptBomba/Shader-GTNH-Gentle-Atomosphere/releases),
drop it (still zipped) into `.minecraft/shaderpacks`, then pick it under
*Options → Video Settings → Shader Packs*. Profiles: **Minimal** (no cast shadows,
lowest cost), **Natural** (default), **Atmospheric** (two cloud layers, detailed
reflections). Menus are available in English and Brazilian Portuguese.
