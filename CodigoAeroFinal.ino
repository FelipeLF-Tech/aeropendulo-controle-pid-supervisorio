/*
 * ============================================================
 * CONTROLADOR PID - AERO-PÊNDULO
 * ============================================================
 * Compatível com o Supervisório Processing existente
 *
 * Protocolo RECEBE : "CMD:modo,SP,PWM,Kp,Ki,Kd\n"
 * modo 0 = Malha Aberta (PWM manual)
 * modo 1 = Malha Fechada (PID)
 *
 * Protocolo ENVIA  : "modo,SP,PV,MV,0,0,0,9600\n"  (8 campos)
 *
 * Ganhos iniciais  : Kp=0.2 | Ki=0.5 | Kd=0.042
 * Serial           : 9600 baud (padrão Arduino)
 *
 * Freio a 90°:
 * - Integral congelada quando |erro| < 4° (zona final)
 * - Derivativo x2 quando sobe perto do alvo (|erro| < 10°)
 * ============================================================
 */

// --- 1. PINOS ---
const int pinoSensor = A0;
const int pinoMotor  = 3;

// --- 2. LIMITES FIXOS ---
const float LIMITE_ANGULO = 90.0;
float LIMITE_PWM    = 90;
const float FORCA_MINIMA_SUSTENTACAO = 60.0; // Força para manter em 90º

// --- 3. GANHOS DINÂMICOS (atualizados pelo Processing) ---
float Kp = 0.09;
float Ki = 0.18;
float Kd = 0.085;

// --- 4. ESTADO DO CONTROLADOR ---
int   modo          = 1;    // 1=Malha Fechada | 0=Malha Aberta
float setPointGraus = 0.0;
int   pwmManual     = 0;

// --- 5. VARIÁVEIS INTERNAS DO PID ---
float anguloAnterior = 0.0;
float D_anterior     = 0.0;
float forcaIntegral  = 0.0;

// --- 6. CONTROLE DE TEMPO (50 Hz) ---
unsigned long tempoAnterior = 0;
const float         Ts              = 0.02;
const unsigned long intervaloMicros = 20000;

// ============================================================
void setup() {
  Serial.begin(9600);
  Serial.setTimeout(10);

  pinMode(pinoSensor, INPUT);
  pinMode(pinoMotor,  OUTPUT);
  analogWrite(pinoMotor, 0);

  tempoAnterior = micros();
}

// ============================================================
// PARSER: lê "CMD:1,45.0,0,0.20,0.50,0.042" e atualiza estado
// ============================================================
void parsearComando(String raw) {
  raw.trim();
  if (!raw.startsWith("CMD:")) return;

  String dados = raw.substring(4);
  float vals[6] = {0, 0, 0, 0, 0, 0};
  int campo = 0;
  int inicio = 0;

  for (int i = 0; i <= (int)dados.length() && campo < 6; i++) {
    if (i == (int)dados.length() || dados.charAt(i) == ',') {
      vals[campo] = dados.substring(inicio, i).toFloat();
      campo++;
      inicio = i + 1;
    }
  }

  if (campo < 6) return; // Pacote incompleto, ignora

  // Aplica modo
  int novoModo = (int)vals[0];
  if (novoModo == 0 || novoModo == 1) modo = novoModo;

  // Aplica SP (só em malha fechada)
  float novoSP = vals[1];
  if (novoSP >= 0.0 && novoSP <= LIMITE_ANGULO) {
    if (novoSP != setPointGraus) forcaIntegral = 0.0; // Reseta integral na mudança de alvo
    setPointGraus = novoSP;
  }

  // Aplica PWM manual (só em malha aberta)
  int novoPWM = (int)vals[2];
  if (novoPWM >= 0 && novoPWM <= (int)LIMITE_PWM) pwmManual = novoPWM;

  // Aplica ganhos
  if (vals[3] >= 0.0 && vals[3] <= 50.0) Kp = vals[3];
  if (vals[4] >= 0.0 && vals[4] <= 50.0) Ki = vals[4];
  if (vals[5] >= 0.0 && vals[5] <= 50.0) Kd = vals[5];
}

// ============================================================
void loop() {

  // ----------------------------------------------------------
  // BLOCO 1 – RECEPÇÃO SERIAL (Processing → Arduino)
  // ----------------------------------------------------------
  if (Serial.available() > 0) {
    String texto = Serial.readStringUntil('\n');
    parsearComando(texto);
  }

  // ----------------------------------------------------------
  // BLOCO 2 – CLOCK DO CONTROLADOR (50 Hz rigorosos)
  // ----------------------------------------------------------
  if (micros() - tempoAnterior >= intervaloMicros) {
    tempoAnterior += intervaloMicros;

    // --- A. LEITURA DO SENSOR ---
    int   leituraADC  = analogRead(pinoSensor);
    float anguloAtual = (float)map(leituraADC, 0, 1023, 0, 270);

    // Sem clamp superior: PID enxerga overshoot além de 90° e gera erro negativo
    if (anguloAtual < 0.0) anguloAtual = 0.0;

    float sinalPWM = 0.0;

    // ----------------------------------------------------------
    // MALHA ABERTA: Processing controla o PWM diretamente
    // ----------------------------------------------------------
    if (modo == 0) {
      sinalPWM      = (float)pwmManual;
      forcaIntegral = 0.0;

    // ----------------------------------------------------------
    // MALHA FECHADA: Feed-Forward + PID com freio em 90°
    // ----------------------------------------------------------
    } else {

      // B. ERRO (livre além de 90° para corrigir overshoot)
      float erroAtual = setPointGraus - anguloAtual;

      // C. FEED-FORWARD GRAVITACIONAL
      //    sin(SP) × 55 sustenta a haste contra a gravidade estaticamente
      float feedForward = sin(setPointGraus * (PI / 180.0)) * 55.0;

      // D. PROPORCIONAL
      float P = Kp * erroAtual;

      // E. INTEGRAL COM FREIO NA ZONA FINAL
      //    Congela a memória quando |erro| < 4°
      //    Evita que o acúmulo empurre o pêndulo além de 90°
      if (abs(erroAtual) > 4.0) {
        forcaIntegral += Ki * erroAtual * Ts;
      }
      if      (forcaIntegral >  LIMITE_PWM) forcaIntegral =  LIMITE_PWM;
      else if (forcaIntegral < -LIMITE_PWM) forcaIntegral = -LIMITE_PWM;

      float I = forcaIntegral;

      // F. DERIVATIVO DA MEDIÇÃO + FILTRO EMA
      //    Quando perto do alvo e ainda subindo, dobra o freio
      float velocidadeAngular = (anguloAtual - anguloAnterior) / Ts;
      float ganhoD = Kd;
      if (abs(erroAtual) < 10.0 && velocidadeAngular > 0.0) {
        ganhoD = Kd * 2.0; // Freio reforçado na chegada a 90°
      }
      float D_cru      = -(ganhoD * velocidadeAngular);
      float D_filtrado  = 0.3 * D_anterior + 0.7 * D_cru;
      D_anterior        = D_filtrado;

      // G. SOMA FINAL
      sinalPWM = feedForward + P + I + D_filtrado;
    }

    // Se o braço entrar na zona alta (acima de 65º), começamos a reduzir o limite.
    if (anguloAtual >= 65.0) {
      // O map vai espremendo o limite de 255 até 60 de forma progressiva!
      LIMITE_PWM = map(anguloAtual, 65, 90, 255, FORCA_MINIMA_SUSTENTACAO);
      
      // Trava de segurança para garantir que a matemática não baixe de 60
      if (LIMITE_PWM < FORCA_MINIMA_SUSTENTACAO) LIMITE_PWM = FORCA_MINIMA_SUSTENTACAO;
    }

    // --- SATURAÇÃO DE HARDWARE ---
    if      (sinalPWM > LIMITE_PWM) sinalPWM = LIMITE_PWM;
    else if (sinalPWM < 0.0)        sinalPWM = 0.0;

    // --- ATUAÇÃO ---
    analogWrite(pinoMotor, (int)sinalPWM);

    // --- MEMÓRIA DO SENSOR ---
    anguloAnterior = anguloAtual;

    // ----------------------------------------------------------
    // BLOCO 3 – ENVIO PARA O PROCESSING (8 campos obrigatórios)
    // Formato: "modo,SP,PV,MV,0,0,0,9600\n"
    // val[0]=modo | val[1]=SP | val[2]=PV | val[3]=MV | val[7]=baud
    // ----------------------------------------------------------
    Serial.print(modo);            Serial.print(",");
    Serial.print(setPointGraus);   Serial.print(",");
    Serial.print(anguloAtual);  Serial.print(",");
    Serial.print((int)sinalPWM);   Serial.print(",");
    Serial.print(Kp);               Serial.print(",");
    Serial.print(Ki);               Serial.print(",");
    Serial.print(Kd);               Serial.print(",");
    Serial.println(9600);
  }
}
