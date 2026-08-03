# Oceanhorn: Chronos Dungeon — instalação (BYO-data)

Este pacote contém **apenas o port**. O jogo é seu e não é distribuído aqui.

## 1. Copie o pacote

Descompacte o ZIP na pasta de ports do seu aparelho:

- ArkOS / muOS / Batocera e afins: `/roms/ports/`
- NextOS Elite: `.sh` em `/storage/roms/ports_scripts/`, pasta `oceanhorn` em `/storage/roms/ports/`

## 2. Coloque seu APK

Copie o APK/APKM/XAPK da sua cópia legal do jogo
(`com.FDGEntertainment.OceanhornChronosDungeon.gp`, versão 4.0b54, arm64-v8a)
para:

```text
ports/oceanhorn/gamedata/
```

O nome do arquivo não importa: o NXExtract identifica a versão pelo conteúdo.

## 3. Rode pelo menu

Na primeira execução o extrator valida ABI, tamanhos e hashes, instala os dados
de forma transacional (com barra de progresso) e abre o jogo. O seu arquivo
original **nunca é apagado**. Se o APK for de outra build, o erro diz
exatamente isso — "build diferente" — em vez de fingir que falta arquivo.

**SELECT + START** salva e volta ao frontend.

## Saves

Ficam em `ports/oceanhorn/userdata/` e sobrevivem a atualizações do port.

## Aparelhos

Validado fisicamente no **R36S/ArkOS** (Mali-G31, 640×480) e no **NextOS Elite**
(Mali-450, 1280×720) — o mesmo binário nos dois. Nos demais CFWs AArch64 o
launcher detecta vídeo, áudio, RAM e controle em runtime; deve funcionar, mas só
declaramos validado o que foi rodado de verdade.
