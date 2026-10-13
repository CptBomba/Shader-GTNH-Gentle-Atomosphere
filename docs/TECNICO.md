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
| `composite` / `composite1` | `bloom_extract` / `bloom_blur` | colortex2 / colortex3 | Extração e blur horizontal do bloom (resolução integral) |
| `final` | `post_final` | tela | FXAA, nitidez adaptativa, blur vertical do bloom e compressão de altas luzes |

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

## Água (`lib/water.glsl`)

- Só a face de cima da água vanilla (`gentleUp > 0.8`) recebe o efeito;
  cachoeiras e fluidos de mods ficam com a aparência original.
- Normais de onda analíticas com harmônicas que somem antes do limite de
  Nyquist (sem cintilação à distância).
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
"tudo no máximo", e compila os 138 pontos de entrada com `glslangValidator`.
Isso garante que o código compila, mas não substitui testar no jogo:
interiores, nascer/pôr do sol, chuva, água rasa e funda, terceira pessoa e
desempenho com as mesmas opções.
