# Changelog

## 0.8.0

### Tochas e luz artificial
- **Corrigido:** o interior de bases piscava. A tremulação foi retirada da luz
  nas paredes, que agora é estável.
- **Halo nas chamas:** chamas de tochas (inclusive a tocha de pedra do
  Tinkers), fogo, lava, glowstone, lâmpada de redstone acesa, fornalha acesa e
  partículas de chama/lava ganham um brilho quente e suave em volta. Só os
  texels claros e quentes brilham (o cabo da tocha e a pedra não).
- As chamas tremulam com brilho próprio, cada tocha no seu ritmo; a lava
  pulsa devagar. Uma tocha segurada na mão também brilha.
- Nova opção *Brilho das chamas* (Minimal 0,5, Natural 1,0, Atmospheric 1,5).
- O bloom passou a ser calculado em 1/4 da resolução, com um halo mais
  largo e um núcleo estreito, sem custo relevante. Novo passe `composite2`.

## 0.7.0

### Vegetação
- Rajadas de vento que percorrem os campos em ondas, tremor contínuo das
  folhas e lâminas de grama, vento mais forte na chuva. Vento padrão do
  perfil Natural de 0,55 para 0,75 (Atmospheric 1,0).
- Folhas e grama ficam levemente translúcidas contra o sol, e a vegetação
  ao sol ganha um pouco de saturação.
- Novos blocos com vento: arbusto seco, flores e folhagens do Biomes O'
  Plenty (`flowers`, `flowers2`, `foliage`). Vitórias-régias boiam na água.

### Água e reflexos
- Ondulações finas perto da câmera, mais agitadas na chuva.
- Reflexo nítido do sol que cintila nas ondas, além do brilho largo.

### Tochas e luz artificial
- Novo menu *Tochas e lâmpadas*.
- Luz de tochas, lâmpadas e lava mais quente e um pouco mais forte perto da
  fonte, sem alterar a luz do dia ao ar livre nem a cor das próprias fontes.
- Tremulação leve e irregular da luz (cada ambiente oscila de forma
  independente). Desligável.
- Luz na mão: segurar tocha, glowstone ou qualquer item que emita luz
  ilumina ao redor do jogador.
- *Sombras de luzes locais* (experimental) foi para o menu novo.

## 0.6.0

Primeira versão pública no GitHub.

### Sombras e luz
- **Sem vazamento de luz em interiores.** Superfícies que o céu quase não
  alcança (luz do céu 12 ou menos) nunca recebem sol direto. Acaba com manchas
  claras em paredes e tetos de bases, cavernas e construções.
- O cálculo de sombras é pulado automaticamente em ambientes internos e
  subterrâneos, economizando GPU onde se passa a maior parte do tempo no GTNH.
- Faces viradas para o lado oposto ao sol ficam sempre do lado sombreado:
  menos serrilhado em faces rasantes e sombreamento direcional também no
  perfil Minimal.
- Sombras levemente mais claras (tom de céu), mantendo o visual do Minecraft.

### Água
- Profundidade: margens rasas mais transparentes, água funda mais densa e
  azul, usando a profundidade real do leito.
- O brilho do sol na água mantém a intensidade depois da mistura de
  transparência.

### Nuvens
- Formações no limite da cobertura diminuem de tamanho em vez de virarem
  blocos translúcidos tipo vidro.
- Faces iluminadas pela direção real do sol, leve textura na superfície,
  brilho quente perto do sol no nascer e no pôr do sol e nuvens mais cinzas
  na chuva.

### Padrões e repositório
- *Sombras de luzes locais* desligada em todos os perfis: depende do mod
  complementar Gentle Lights, que não é distribuído, e é custosa. O sampler
  do complemento só é solicitado quando a opção está ligada.
- README para distribuição, notas técnicas, script de validação
  (`tools/validate.py`), empacotamento (`tools/build.py`) e GitHub Actions
  gerando o ZIP a cada push e anexando à Release em tags `v*`.
- Finais de linha normalizados (LF).

## 0.5.5

- Compatibilidade com GTNH 2.9.0-RC-2 e Angelica 2.2.28.
- Grama e folhas preservam as cores de mipmap já corrigidas pelo Angelica.
- Plano receptor das sombras calculado pela normal da face (faces opacas) ou
  pelas derivadas da posição (plantas animadas), corrigindo pontilhado em
  paredes próximas.
- Lista de biomas RWG da instância (25 IDs) mantida; IDs do GalaxySpace
  intercalados continuam protegidos.
