# Oceanhorn: Chronos Dungeon — instalação (BYO-data)

Este pacote contém **apenas o port**: launcher e runtime de compatibilidade.
O jogo é seu e não é distribuído aqui.

## 1. Copie o pacote

Descompacte o ZIP na pasta de ports do seu aparelho:

- ArkOS / muOS / Batocera e afins: `/roms/ports/`
- NextOS Elite: `.sh` em `/storage/roms/ports_scripts/`, pasta `oceanhorn` em `/storage/roms/ports/`

Fica assim:

```text
ports/
├── Oceanhorn Chronos Dungeon.sh
└── oceanhorn/
    ├── run.sh
    ├── oceanhorn-universal
    ├── gamedata/LEIA-ME.txt
    └── userdata/
```

## 2. Traga os dados do seu APK

Do seu APK legal (`com.FDGEntertainment.OceanhornChronosDungeon.gp`, 4.0b54, arm64-v8a):

| Do APK | Para |
|---|---|
| `lib/arm64-v8a/libunity.so` | `ports/oceanhorn/` |
| `lib/arm64-v8a/libil2cpp.so` | `ports/oceanhorn/` |
| `lib/arm64-v8a/libmain.so` | `ports/oceanhorn/` |
| `assets/bin/Data/` (árvore inteira) | `ports/oceanhorn/bin/Data/` |

## 3. Rode pelo menu

O jogo aparece na lista de Ports. **SELECT + START** salva e volta ao frontend.

## Saves

Ficam em `ports/oceanhorn/userdata/`. Atualizar o port não apaga essa pasta —
mas fazer backup dela antes de atualizar continua sendo boa prática.

## Aparelhos

Validado fisicamente no **R36S/ArkOS** (Mali-G31, 640×480) e no **NextOS Elite**
(Mali-450, 1280×720). Em outros CFWs AArch64 o launcher detecta vídeo, áudio,
RAM e controle em runtime — deve funcionar, mas ainda não temos prova física;
se rodar no seu, conte pra gente.
