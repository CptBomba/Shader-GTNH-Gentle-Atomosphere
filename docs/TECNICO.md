# Notas técnicas

Referência para quem quer entender ou modificar o pack. Alvo: GTNH 2.9.0-RC-2,
Minecraft 1.7.10, Angelica 2.2.28 (port do Iris). Todo o código é GLSL 1.20.

## Pipeline

| Passe | Programa | Saída | Função |
|---|---|---|---|
| `shadow` | `program/shadow.*` | shadowtex0 | Silhuetas de terreno, plantas (com vento), entidades e TESRs. Translúcidos ficam de fora |
| `gbuffers_skybasic/skytextured` | `program/geometry.*` | colortex0, colortex1 | Céu nativo; sol, lua e estrelas (`renderStage` 4–6) são acumulados em colortex1 (RGBA16F) |
| `gbuffers_terrain/block/entities` | `program/geometry.*` | colortex0 | Lightmap original, tom quente leve, alívio do sombreamento vanilla, sol/sombra, oclusão local opcional |
| `deferred` | `program/atmosphere.*` | colortex0, colortex4 | Gradiente do céu + astros + nuvens analíticas nos pixels de céu; colortex4 é um snapshot opaco imutável |
| `gbuffers_water` | `program/geometry.*` + `lib/water.glsl` | colortex0 | Ondas, profundidade, reflexos (SSR em colortex4/depthtex1) e brilho do sol |
| `composite` | `bloom_extract` | colortex2 | Bloom do que é muito claro + fontes de halo (colortex5), reduzidos a 1/4 no canto inferior esquerdo |
| `composite1` / `composite2` | `bloom_blur` | colortex3 / colortex6 | Gaussiana separável (sigma 16 px na tela, 13 amostras) só nessa área |
| `final` | `post_final` | tela | FXAA, nitidez adaptativa, halo (núcleo de colortex2 + halo largo de colortex6) e compressão de altas luzes |

Os pontos de entrada (`gbuffers_*.fsh/.vsh`) apenas definem macros (`GENTLE_LIT`,
`GENTLE_TERRAIN`, `GENTLE_WATER`, `GENTLE_ENTITY`, `GENTLE_RECEIVER`...) e incluem
o programa compartilhado. Em `world-1/` e `world1/` também definem
`GENTLE_NON_EARTH`, o que desliga todos os efeitos.

## Onde os efeitos se aplicam

`gentleEarth()` (`lib/environment.glsl`) libera os efeitos apenas com skylight,
sem teto e em uma lista de biomas conhecida: vanilla, Biomes O' Plenty,
Thaumcraft (190, 192, 193) e os 25 biomas RWG da configuração do GTNH. Biomas
desconhecidos ficam com a renderização nativa. A opção `EARTH_EFFECTS` desliga
tudo para dimensões de mods que reutilizam IDs da Superfície.

Materiais (`block.properties`, IDs de material, não do registro):

| ID | Blocos | Uso |
|---|---|---|
| 10001 | folhas (dicionário `treeLeaves` do Angelica) | vento leve, luz de dois lados |
| 10002 | grama, mudas, flores, flores do Botania | vento com a base presa |
| 10003 | trigo, cenoura, batata | vento com a base presa |
| 10004 | água parada e corrente | superfície de água |
| 10005 | vitória-régia | balanço e flutuação na água |
| 10006 | tochas (vanilla, redstone, pedra do Tinkers), fogo, glowstone, lâmpada de redstone acesa, fornalha acesa | halo e tremulação nos texels de chama |
| 10007 | lava | halo mais fraco e pulsação lenta |

O ID 10002 também cobre arbusto seco e as flores/folhagens do Biomes O' Plenty
(`flowers`, `flowers2`, `foliage`) quando `MOD_FLOWERS=1`.

## Sol e sombras (`lib/lighting.glsl`)

- Mapa 2048, distância 64 blocos, `shadowIntervalSize` de um texel. Filtro
  B-spline quadrático de 9 amostras com plano receptor por amostra.
- Bias pela normal e pela direção da luz, ambos escalados por `SHADOW_BIAS`.
- `gentleSkyAccess`: luz do céu 15–14 usa o mapa de sombras, 13 faz a transição
  e 12 ou menos é sempre sombra. Isso elimina vazamentos de luz e evita as 9
  leituras do mapa em interiores.
- `gentleFacing`: faces opostas ao sol ficam na sombra (plantas e folhas são de
  dois lados e ficam de fora).
- A resposta é um multiplicador suave: sombra `(0.75, 0.82, 0.91)`, sol
  ligeiramente quente, enfraquecendo com a chuva. Luz de tochas forte e
  superfícies fullbright são protegidas.

## Luz artificial (`lib/blocklight.glsl`)

- Tudo parte da textura de lightmap do próprio jogo, então brilho, gama,
  visão noturna e relâmpagos continuam iguais ao vanilla.
- `gentleHeldLight`: o nível de luz do item na mão (`heldBlockLightValue`,
  `heldBlockLightValue2`) menos a distância em blocos vira um nível de luz
  virtual; vale o maior entre ele e o nível real. Sem oclusão.
- `gentleBlockLight`: compara a luminância só-bloco e só-céu do lightmap. Onde
  a luz artificial domina, aplica um tom âmbar (mais claro perto da chama) e
  um reforço de até 28% no nível 14. O nível 15 (lava, overlays fullbright,
  a própria fonte) é preservado. A luz nas superfícies não tremula: como o
  lightmap não diz de qual fonte vem a luz, a oscilação fazia o ambiente
  inteiro piscar junto.
- Halo: terreno (materiais 10006/10007), partículas fullbright e a mão com
  item luminoso escrevem em colortex5 os texels claros e quentes
  (`gentleFlameMask`), com tremulação por bloco (`gentleFlicker`, fase pelo
  hash da posição) e um reforço moderado com a distância. Terreno, entidades
  e mão escrevem zero no resto, então objetos na frente tapam o halo.

## Vento (`lib/vegetation.glsl`)

Inclinação lenta + frentes de rajada (~30 blocos entre cristas) + tremor
rápido. Folhas usam fase por vértice em espaço de mundo (vértices
compartilhados se movem juntos, sem frestas). A mesma função é usada no passe
de sombras, então as sombras das plantas acompanham o movimento.

## Água (`lib/water.glsl`)

- Só a face de cima da água vanilla (`gentleUp > 0.8`) recebe o efeito;
  cachoeiras e fluidos de mods ficam com a aparência original.
- Normais de onda analíticas com cinco harmônicas (mais uma com chuva) que
  somem antes do limite de Nyquist (sem cintilação à distância).
- Brilho do sol em dois lóbulos: largo (expoente 96) e o disco do sol
  (expoente 900), que vira cintilação nas ondas.
- Profundidade = distância entre a superfície e o leito opaco (`depthtex1`).
  Ajusta alpha (raso mais claro, fundo até 0.88) e escurece levemente a cor.
- Reflexo: marcha em espaço de tela com 12 ou 24 passos e refinamento binário;
  fora da tela usa o gradiente do céu. Fresnel compensado pela transparência.

## Nuvens (`lib/cloud_shapes.glsl`)

Interseções analíticas raio–caixa com cantos chanfrados (12 semiplanos), sem
ray marching nem texturas. Campo em células de 128 blocos, padrão que se repete
a cada 2048 blocos, com 2 a 4 caixas por formação. Iluminação por face (topo,
lado, base), direção do sol, textura de ruído leve, dispersão quente perto do
sol, névoa pela distância e cobertura que cresce com a chuva.

## Tempo e animação

O Angelica zera `frameTimeCounter` a cada hora. Todas as animações (vento,
ondas, nuvens) usam frequências com número inteiro de ciclos em 3600 s, então
não há salto quando o contador volta a zero.

## Luzes locais (experimental)

Com `LOCAL_LIGHT_SHADOWS > 0`, o shader lê a textura
`gtnhgentlelights:lightgrid` (256×512 RGBA8) publicada pelo mod complementar
Gentle Lights pelo sampler `noisetex`. O cabeçalho `(97, 2, 255)` identifica o
protocolo 2; dois volumes 32³ com até 8 emissores cada são percorridos por DDA
para escurecer o lightmap atrás de blocos opacos. Sem o mod, o cabeçalho não
confere e o lightmap vanilla é mantido. O mod ainda não é distribuído neste
repositório.

## Validação

`python3 tools/validate.py` resolve os `#include`, aplica os perfis Minimal,
Natural e Atmospheric, os valores padrão e as combinações "tudo no mínimo" e
"tudo no máximo", e compila os 144 pontos de entrada com `glslangValidator`.
Isso garante que o código compila, mas não substitui testar no jogo:
interiores, nascer/pôr do sol, chuva, água rasa e funda, terceira pessoa e
desempenho com as mesmas opções.
