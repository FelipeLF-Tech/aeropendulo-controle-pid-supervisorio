# Aeropêndulo — Controle PID e supervisório

Projeto de controle de um aeropêndulo com firmware Arduino e interface supervisória em Processing.

## Componentes
- `CodigoAeroFinal.ino`: firmware PID. O cabeçalho descreve os comandos seriais `CMD:modo,SP,PWM,Kp,Ki,Kd` e os dados transmitidos pelo Arduino.
- `PendulumsoftFINAL.pde`: interface Processing para comunicação serial, visualização de variáveis, ajuste de modo/parâmetros e gravação CSV.

## Execução
1. Abra o `.ino` no Arduino IDE e configure a placa e a porta serial correspondentes ao hardware.
2. Abra o `.pde` no Processing com a biblioteca `processing.serial` disponível.
3. Selecione a mesma porta e baud rate (9600) nos dois lados. Feche o Serial Monitor da IDE antes de conectar o Processing.
4. Teste primeiro sem conectar cargas/motores, depois valide com o circuito e os procedimentos de segurança do laboratório.

## Autoria e status
Código recuperado de pastas pessoais de Arduino/Processing. Confirmar autoria individual e quais trechos foram desenvolvidos com assistência de IA ou em grupo antes de publicar. Este repositório contém os fontes selecionados; existem variantes de desenvolvimento não incluídas.

## Estado de validação e próximos passos
Conferir firmware e supervisório em conjunto, revisar pinos e segurança do atuador, adicionar screenshot/vídeo autorizado e licença somente após escolha. Não incluir dumps de dados sem conferir privacidade.
