# Changelog

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
