# Oeste Saiyajin — base jogável (Godot 4.3)

## Abrir e rodar
1. Abra a pasta no Godot 4.3+ (Importar > project.godot) e aperte F5.
2. No PC: WASD mover, setas câmera, Espaço pular, J soco, K ki (segure para esfera), L esquiva,
   C carga, F voo, G Super Saiyajin, R correr, E interagir.

## Exportar para Android
Editor > Gerenciar modelos de exportação (instale os de 4.3), configure JDK 17 + Android SDK em
Editor Settings > Export > Android, crie um keystore de debug, depois Projeto > Exportar > Android.
Orientação já está em paisagem; renderer Compatibility (GLES3) e 30 FPS (Engine.max_fps em main.gd).

## Controles touch
Esquerda: joystick flutuante. Direita (área livre): arrastar gira a câmera.
SOCO (combo soco/soco/chute) · PULO · KI (toque = rajada, segurar = esfera) · ESQUIVA ·
CORRER (liga/desliga) · CARGA (segurar, recupera ki) · VOO (liga/desliga; PULO sobe, ESQUIVA desce) · SSJ.
SSJ: custa ki, drena ki aos poucos, dá x2,6 de dano, x1,5 de velocidade, menos dano recebido.

## Estrutura
main.gd (montagem) · world.gd (terreno, cidade, fazenda, natureza) · rig.gd (boneco + animações + aura)
player.gd · npc.gd (NPCs e bandidos) · proj.gd (ki) · ui.gd / touch.gd (HUD, diálogos, controles).

## Limites desta versão
- O modelo é procedural (formas simples). Para qualidade final, importe um GLB riggado e adapte rig.gd.
- Prédios não têm interior. Sem áudio. Sem salvamento.
- Escrito sem poder executar o Godot aqui: espere pequenos ajustes/erros de script no primeiro run.
