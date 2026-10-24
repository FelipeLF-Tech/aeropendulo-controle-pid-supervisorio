// ==============================================================
// SUPERVISÓRIO PROCESSING - INTERFACE DE CONTROLE DIGITAL
// ==============================================================
import processing.serial.*; 

Serial minhaPorta;          
boolean conectado = false;  
boolean parametrosSincronizados = false; 
boolean mostrarInfo = false; 

// --- NOVO: Variáveis para Exportação Excel ---
PrintWriter arquivoCSV;
boolean gravandoDados = false;
int contadorTempo = 0;
String nomeArquivo = "";

// Dados Lidos do Arduino
int modo_real = 1;          // 1 = Fechada, 0 = Aberta
float pv_angulo = 0.0;      
float sp_atual = 0.0;       
int mv_pwm = 0;             
long baud_lido = 0; 

// Dados de Interface (Editáveis)
int modo_UI = 1;            
float target_SP = 0.0;      
int target_PWM = 0;         
float target_Kp = 0.106 ;      
float target_Ki = 0.22;      
float target_Kd = 0;      

// Gráficos
int maxPontos = 250;        
float[] histPV = new float[maxPontos]; 
float[] histSP = new float[maxPontos]; 
float[] histMV = new float[maxPontos]; 

color bgMain = color(230, 230, 230);   
color panelBg = color(245, 245, 245);  
color border = color(150, 150, 150);   
color textDark = color(30, 30, 30);    
color pBlue = color(0, 100, 200);      
color pRed = color(200, 50, 50);       

PFont fontBold, fontNorm, fontMath;    

// Foco do Teclado
String activeInput = "";   
String inputBuffer = "";   

void setup() {
  size(1100, 750); 
  smooth(4);        
  
  fontBold = createFont("Arial Bold", 14); 
  fontNorm = createFont("Arial", 12);      
  fontMath = createFont("Georgia Italic", 20); 
  
  for(int i = 0; i < maxPontos; i++) { 
    histPV[i] = 0; histSP[i] = 0; histMV[i] = 0; 
  }
  
  try {
    minhaPorta = new Serial(this, "COM7", 9600);
    minhaPorta.bufferUntil('\n');                  
    conectado = true;                              
  } catch (Exception e) { 
    conectado = false;                             
    println("Falha ao abrir a porta. Iniciando modo Offline."); 
  }
}

void draw() {
  background(bgMain); 
  desenharCabecalho(); 
  desenharMalha1(20, 80, 300, 300);
  desenharGraficos(340, 80, 740, 300);
  desenharParametrosSintonia(20, 400, 300, 300);
  desenharImagemPID(340, 400, 400, 300);
  desenharConfigSerial(760, 400, 320, 300);
  desenharJanelaInfo();
}

void desenharPainel(float x, float y, float w, float h, String titulo) {
  fill(panelBg); stroke(border); strokeWeight(1); 
  rect(x, y, w, h);                               
  fill(220); rect(x, y, w, 30);                   
  fill(textDark); textFont(fontBold); textAlign(LEFT, CENTER); 
  text(titulo, x + 10, y + 15);                   
}

void desenharCabecalho() {
  fill(200); noStroke(); rect(0, 0, width, 50);   
  stroke(border); line(0, 50, width, 50);         
  fill(textDark); textFont(fontBold); textAlign(LEFT, CENTER);
  text("INTERFACE DE CONTROLE DIGITAL DO AERO-PÊNDULO", 20, 25); 
  
  fill(240); stroke(border); rect(width - 150, 10, 130, 30); 
  fill(textDark); textAlign(CENTER, CENTER); text("INFO - SOBRE", width - 85, 25);
}

void desenharMalha1(float x, float y, float w, float h) {
  desenharPainel(x, y, w, h, "MODO DE OPERAÇÃO: MALHA 1"); 
  
  // ==========================================
  // BOTÃO: MALHA ABERTA / FECHADA
  // ==========================================
  fill(240); stroke(border); rect(x + 10, y + 40, 280, 30); 
  if (modo_UI == 1) { // FECHADA
    fill(pBlue); rect(x + 150, y + 42, 135, 26);             
    fill(textDark); textAlign(CENTER, CENTER); text("ABERTA (MAN)", x + 80, y + 55); 
    fill(255); text("FECHADA (PID)", x + 217, y + 55);                 
  } else { // ABERTA
    fill(pBlue); rect(x + 15, y + 42, 135, 26);              
    fill(255); textAlign(CENTER, CENTER); text("ABERTA (MAN)", x + 80, y + 55); 
    fill(textDark); text("FECHADA (PID)", x + 217, y + 55);                 
  }
  
  textAlign(RIGHT, CENTER); fill(textDark); 
  text("SP (Alvo):", x + 100, y + 110);
  text("PV (Sensor):", x + 100, y + 150);
  text("MV (PWM):", x + 100, y + 190);
  
  // CAIXA DO SETPOINT 
  if (modo_UI == 1) { fill(255); stroke(pBlue); strokeWeight(2); } 
  else { fill(230); stroke(border); strokeWeight(1); } 
  
  rect(x + 120, y + 95, 80, 30); 
  fill(modo_UI == 1 ? pBlue : textDark); textAlign(CENTER, CENTER); 
  String txtSP = activeInput.equals("SP") ? inputBuffer + (frameCount % 60 < 30 ? "_" : "") : nf(target_SP, 0, 1);
  text(txtSP, x + 160, y + 110); 
  
  // CAIXA DO PV 
  fill(240); stroke(border); strokeWeight(1); rect(x + 120, y + 135, 80, 30); 
  fill(pRed); text(nf(pv_angulo, 0, 1), x + 160, y + 150); 
  
  // CAIXA DO PWM 
  if (modo_UI == 0) { fill(255); stroke(pBlue); strokeWeight(2); } 
  else { fill(230); stroke(border); strokeWeight(1); } 
  
  rect(x + 120, y + 175, 80, 30);
  fill(modo_UI == 0 ? pBlue : textDark);
  String txtMV = activeInput.equals("MV") ? inputBuffer + (frameCount % 60 < 30 ? "_" : "") : str(modo_UI == 0 ? target_PWM : mv_pwm);
  text(txtMV, x + 160, y + 190); 
  
  // --- NOVO: BOTÃO GRAVAR EXCEL ---
  if (gravandoDados) {
    fill(255, 100, 100); stroke(pRed); strokeWeight(2);
  } else {
    fill(240); stroke(border); strokeWeight(1);
  }
  rect(x + 20, y + 240, 260, 40);
  
  fill(textDark); textFont(fontBold); textAlign(CENTER, CENTER);
  if (gravandoDados) {
    text("PARAR GRAVAÇÃO (Gravando...)", x + 150, y + 260);
  } else {
    text("INICIAR GRAVAÇÃO (Excel CSV)", x + 150, y + 260);
  }
}

void desenharGraficos(float x, float y, float w, float h) {
  desenharPainel(x, y, w, h, "GRÁFICOS DE TENDÊNCIA");
  
  fill(255); stroke(border); rect(x + 20, y + 50, w - 40, 100);
  fill(textDark); textAlign(LEFT, TOP); textFont(fontNorm); text("PV / SP (°)", x + 30, y + 55);
  
  fill(255); stroke(border); rect(x + 20, y + 170, w - 40, 100);
  fill(textDark); textAlign(LEFT, TOP); text("MV (PWM)", x + 30, y + 175);
  
  noFill(); stroke(pBlue); strokeWeight(2); beginShape(); 
  for(int i = 0; i < maxPontos; i++) { 
    float px = map(i, 0, maxPontos-1, x+20, x+w-20); 
    float py = map(histSP[i], 0, 90, y+150, y+50);   
    vertex(px, py); 
  }
  endShape(); 
  
  stroke(pRed); strokeWeight(2); beginShape();
  for(int i = 0; i < maxPontos; i++) {
    float px = map(i, 0, maxPontos-1, x+20, x+w-20);
    float py = map(histPV[i], 0, 90, y+150, y+50);
    vertex(px, py);
  }
  endShape();
  
  stroke(30, 150, 30); strokeWeight(2); beginShape();
  for(int i = 0; i < maxPontos; i++) {
    float px = map(i, 0, maxPontos-1, x+20, x+w-20);
    float py = map(histMV[i], 0, 255, y+270, y+170);
    vertex(px, py);
  }
  endShape();
}

void desenharParametrosSintonia(float x, float y, float w, float h) {
  desenharPainel(x, y, w, h, "PARÂMETROS DE SINTONIA"); 
  
  textAlign(RIGHT, CENTER); fill(textDark); textFont(fontNorm);
  text("Kp:", x + 80, y + 70); 
  text("Ki:", x + 80, y + 110); 
  text("Kd:", x + 80, y + 150);
  
  stroke(border); fill(255); 
  rect(x + 90, y + 55, 80, 30); 
  rect(x + 90, y + 95, 80, 30); 
  rect(x + 90, y + 135, 80, 30); 
  
  fill(pBlue); textAlign(CENTER, CENTER);
  String txtKp = activeInput.equals("KP") ? inputBuffer + (frameCount % 60 < 30 ? "_" : "") : nf(target_Kp, 0, 2);
  String txtKi = activeInput.equals("KI") ? inputBuffer + (frameCount % 60 < 30 ? "_" : "") : nf(target_Ki, 0, 2);
  String txtKd = activeInput.equals("KD") ? inputBuffer + (frameCount % 60 < 30 ? "_" : "") : nf(target_Kd, 0, 2);
  
  text(txtKp, x + 130, y + 70);
  text(txtKi, x + 130, y + 110);
  text(txtKd, x + 130, y + 150);
  
  fill(220); stroke(border); rect(x + 20, y + 240, 120, 40); 
  fill(textDark); text("CANCELAR", x + 80, y + 260);
  fill(pBlue); stroke(border); rect(x + 150, y + 240, 130, 40); 
  fill(255); textFont(fontBold); text("APLICAR", x + 215, y + 260);
  
  fill(100); textFont(fontNorm);
  text("(Digite e tecle ENTER para Enviar)", x + 150, y + 200); 
}

void desenharImagemPID(float x, float y, float w, float h) {
  desenharPainel(x, y, w, h, "EQUAÇÃO PID E FUNÇÃO DE TRANSFERÊNCIA");
  fill(textDark); textFont(fontMath); textAlign(CENTER, CENTER);
  text("u(t) = Kp·e(t) + Ki ∫ e(t)dt + Kd·de(t)/dt", x + w/2, y + 100); 
  stroke(border); line(x + 40, y + 150, x + w - 40, y + 150); 
  text("P(s) = Kt / ( J·s² + b·s + m·g·L )", x + w/2, y + 200);     
}

void desenharConfigSerial(float x, float y, float w, float h) {
  desenharPainel(x, y, w, h, "TELA DE CONFIGURAÇÃO DA SERIAL");
  
  textAlign(RIGHT, CENTER); fill(textDark); textFont(fontNorm);
  text("Porta:", x + 100, y + 100);
  text("Taxa (Baud):", x + 100, y + 160);
  
  fill(255); stroke(border); 
  rect(x + 110, y + 85, 120, 30);
  rect(x + 110, y + 145, 120, 30);
  
  textAlign(CENTER, CENTER);
  if(conectado) { fill(30, 150, 30); text("COM Ativa", x + 170, y + 100); } 
  else { fill(pRed); text("Desconectado", x + 170, y + 100); }
  
  if (conectado && baud_lido > 0) { fill(textDark); text(str(baud_lido), x + 170, y + 160); } 
  else { fill(border); text("---", x + 170, y + 160); }
  
  fill(textDark); textFont(fontBold); textAlign(CENTER, CENTER);
  text("UABJ", x + 170, y + 240); fill(pBlue); text("CONTROLE", x + 170, y + 260);
}

void desenharJanelaInfo() {
  if (!mostrarInfo) return;
  
  fill(0, 200); rect(0, 0, width, height);
  
  float w = 600; float h = 500;
  float x = (width - w) / 2; float y = (height - h) / 2;
  
  fill(255); stroke(0); strokeWeight(2); rect(x, y, w, h, 10);
  
  fill(textDark); textAlign(LEFT, TOP); textFont(fontBold);
  text("PROJETO AERO-PÊNDULO: CONTROLE PID", x + 30, y + 30);
  
  textFont(fontNorm);
  String texto = "Descrição:\n" +
                 "Sistema de controle de um aero-pêndulo\n" +
                 "acionado por motor CC com hélice, utilizando algoritmo PID\n" +
                 "para manter a estabilidade angular com segurança.\n\n" +
                 "Guia de Uso:\n" +
                 "1. Conecte o Arduino via USB e verifique a porta COM.\n" +
                 "2. Utilize o botão 'ABERTA/FECHADA' para alternar modos.\n" +
                 "3. Clique nas caixas azuis para inserir valores (SP, Kp, Ki, Kd).\n" +
                 "4. Pressione ENTER para aplicar novos parâmetros ao sistema.\n" +
                 "5. Utilize o botão 'INICIAR GRAVAÇÃO' para salvar dados em Excel.\n\n" +
                 "Criadores:\n" +
                 "Francielle Silva\n" +
                 "Felipe Lemos\n\n" +
                 "Professor Responsável:\n" +
                 "Prof. Dr. Moisés Tavares";
                 
  text(texto, x + 30, y + 70);
  
  fill(200); rect(x + w/2 - 50, y + h - 60, 100, 40);
  fill(0); textAlign(CENTER, CENTER); text("FECHAR", x + w/2, y + h - 40);
  
  if (mousePressed && mouseX > x+w/2-50 && mouseX < x+w/2+50 && mouseY > y+h-60 && mouseY < y+h-20) {
    mostrarInfo = false;
  }
}

// ==============================================================
// COMUNICAÇÃO DE DADOS (E Gravação CSV)
// ==============================================================
void serialEvent(Serial p) {
  String inStr = trim(p.readStringUntil('\n')); 
  if (inStr != null) { 
    String[] val = split(inStr, ','); 
    
    if (val.length == 8) { 
      modo_real = int(val[0]);
      sp_atual  = float(val[1]); 
      pv_angulo = float(val[2]); 
      mv_pwm    = int(val[3]);
      
      float arduino_Kp = float(val[4]);
      float arduino_Ki = float(val[5]);
      float arduino_Kd = float(val[6]);
      
      baud_lido = int(val[7]); 
      
      if (!parametrosSincronizados) {
        target_Kp = arduino_Kp;
        target_Ki = arduino_Ki;
        target_Kd = arduino_Kd;
        parametrosSincronizados = true; 
        println("SUCESSO: Parâmetros PID importados do Arduino!");
      }
      
      // --- LÓGICA DE GRAVAÇÃO EXCEL ---
      if (gravandoDados) {
        // Grava no formato: Tempo,Modo(1=PID/0=Man),SP,PV,PWM
        String linhaCSV = contadorTempo + "," + modo_real + "," + sp_atual + "," + pv_angulo + "," + mv_pwm;
        arquivoCSV.println(linhaCSV);
        contadorTempo++; // Incrementa (Assume 50 pacotes por segundo)
      }
      
      for(int i = 0; i < maxPontos - 1; i++){ 
        histSP[i] = histSP[i+1]; 
        histPV[i] = histPV[i+1]; 
        histMV[i] = histMV[i+1]; 
      }
      
      histSP[maxPontos - 1] = sp_atual; 
      histPV[maxPontos - 1] = pv_angulo; 
      histMV[maxPontos - 1] = mv_pwm;
    }
  }
}

void enviarComando() {
  if(conectado) {
    String comando = "CMD:" + modo_UI + "," + target_SP + "," + target_PWM + "," + target_Kp + "," + target_Ki + "," + target_Kd + "\n";
    minhaPorta.write(comando); 
  } else {
    println("AVISO: Sistema offline.");
  }
}

// ==============================================================
// GESTÃO DE CLIQUE (Foco e Botões)
// ==============================================================
void mousePressed() {
  salvarDigitacao(); 
  
  // Botão: ABERTA / FECHADA
  if (mouseY > 120 && mouseY < 150 && mouseX > 30 && mouseX < 310) {
    modo_UI = (modo_UI == 1) ? 0 : 1; 
    enviarComando(); 
  }
  
  // Caixa: SETPOINT
  else if (modo_UI == 1 && mouseY > 175 && mouseY < 205 && mouseX > 140 && mouseX < 220) { activeInput = "SP"; inputBuffer = ""; }
  
  // Caixa: PWM MANUAL
  else if (modo_UI == 0 && mouseY > 255 && mouseY < 285 && mouseX > 140 && mouseX < 220) { activeInput = "MV"; inputBuffer = ""; }
  
  // --- NOVO: Botão GRAVAR DADOS ---
  else if (mouseY > 320 && mouseY < 360 && mouseX > 40 && mouseX < 300) {
    if (!gravandoDados) {
      // Inicia Gravação
      nomeArquivo = "Dados_AeroPendulo.csv";
      arquivoCSV = createWriter(nomeArquivo);
      arquivoCSV.println("Amostra,Modo(1=PID 0=Man),Setpoint_Graus,Sensor_Graus,PWM"); // Cabeçalho do Excel
      gravandoDados = true;
      contadorTempo = 0;
      println("Iniciou gravação do arquivo: " + nomeArquivo);
    } else {
      // Para e Salva Gravação
      arquivoCSV.flush(); // Garante que tudo foi escrito
      arquivoCSV.close(); // Fecha o arquivo
      gravandoDados = false;
      println("Gravação finalizada com sucesso!");
    }
  }
  
  // Caixas PID
  else if (mouseY > 455 && mouseY < 485 && mouseX > 90 && mouseX < 170) { activeInput = "KP"; inputBuffer = ""; }
  else if (mouseY > 495 && mouseY < 525 && mouseX > 90 && mouseX < 170) { activeInput = "KI"; inputBuffer = ""; }
  else if (mouseY > 535 && mouseY < 565 && mouseX > 90 && mouseX < 170) { activeInput = "KD"; inputBuffer = ""; }
  else {
    activeInput = ""; 
  }
  
  // Botão Aplicar
  if (mouseX > 170 && mouseX < 300 && mouseY > 640 && mouseY < 680) {
    enviarComando();
  }
  
  // Botão Cancelar
  if (mouseX > 40 && mouseX < 160 && mouseY > 640 && mouseY < 680) {
    target_SP = sp_atual; target_PWM = 0; activeInput = "";
  }
  if (mouseX > width - 150 && mouseX < width - 20 && mouseY > 10 && mouseY < 40) {
    mostrarInfo = !mostrarInfo; 
    return; 
  }
}

// ==============================================================
// GESTÃO DE TECLADO (Digitação de Valores e Auto-Envio)
// ==============================================================
void salvarDigitacao() {
  if (!activeInput.equals("") && !inputBuffer.equals("")) {
    float val = float(inputBuffer); 
    if (!Float.isNaN(val)) { 
      if (activeInput.equals("SP")) target_SP = constrain(val, 0, 90);
      if (activeInput.equals("MV")) target_PWM = int(constrain(val, 0, 255)); 
      if (activeInput.equals("KP")) target_Kp = constrain(val, 0, 50);
      if (activeInput.equals("KI")) target_Ki = constrain(val, 0, 50);
      if (activeInput.equals("KD")) target_Kd = constrain(val, 0, 50);
    }
  }
  activeInput = ""; 
}

void keyPressed() {
  if (!activeInput.equals("")) { 
    if (key == BACKSPACE) {
      if (inputBuffer.length() > 0) {
        inputBuffer = inputBuffer.substring(0, inputBuffer.length() - 1); 
      }
    } 
    else if (key == ENTER || key == RETURN) {
      salvarDigitacao(); 
      enviarComando(); 
    } 
    else if ((key >= '0' && key <= '9') || key == '.' || key == ',') {
      char c = (key == ',') ? '.' : key; 
      if(inputBuffer.length() < 5) {
        inputBuffer += c; 
      }
    }
  }
}
