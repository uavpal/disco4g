#include <WiFi.h>
#include <WiFiUdp.h>
#include <Ticker.h>
#include <Servo.h>

const char* ssid     = "DISCO-027361";
const char* password = "";
IPAddress local_IP(192, 168, 42, 25);
IPAddress gateway(192, 168, 42, 1);
IPAddress subnet(255, 255, 255, 0);
IPAddress primaryDNS(8, 8, 8, 8); //optional
IPAddress secondaryDNS(8, 8, 4, 4); //optional

unsigned int localPort = 8888;      // local port to listen on
#define UDP_TX_PACKET_MAX_SIZE 64
uint8_t packetBuffer[UDP_TX_PACKET_MAX_SIZE]; //buffer to hold incoming packet,
WiFiUDP Udp;

int ledState = LOW;
unsigned long previousMillis = 0;
const long blinkInterval = 1000;

Servo servo1;
const int servo1Pin = 16;
const int servo1Open = 95;
const int servo1Close = 0;

Ticker discoTicker;
int discoCount = 0;
#define ACTION_TIME 1

void setup()
{
  Serial.begin(115200);

  if (!WiFi.config(local_IP, gateway, subnet, primaryDNS, secondaryDNS)) {
    Serial.println("STA Failed to configure");
  }

  Serial.print("Connecting to ");
  Serial.println(ssid);

  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("");
  Serial.println("WiFi connected!");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
  Serial.print("ESP Mac Address: ");
  Serial.println(WiFi.macAddress());
  Serial.print("Subnet Mask: ");
  Serial.println(WiFi.subnetMask());
  Serial.print("Gateway IP: ");
  Serial.println(WiFi.gatewayIP());
  Serial.print("DNS: ");
  Serial.println(WiFi.dnsIP());

  if(Udp.begin(localPort)) {
      Serial.print("UDP Listening on IP: ");
      Serial.println(WiFi.localIP());
  }

  servo1.attach(servo1Pin);
  servo1.write(servo1Close);

  pinMode(LED_BUILTIN, OUTPUT);     // Initialize the LED_BUILTIN pin as an output
}

void servo1Action(bool action) {
  if(action){
    servo1.write(servo1Open);
    //digitalWrite(LED_BUILTIN, LOW);
  }
  else{
    servo1.write(servo1Close);
    //digitalWrite(LED_BUILTIN, HIGH);
  }
}

void loop()
{
  unsigned long currentMillis = millis();
  if (currentMillis - previousMillis >= blinkInterval) {
    previousMillis = currentMillis;
    if (ledState == LOW) {
      ledState = HIGH;  // Note that this switches the LED *off*
    } else {
      ledState = LOW;  // Note that this switches the LED *on*
    }
    digitalWrite(LED_BUILTIN, ledState);
  }
  
  int packetSize = Udp.parsePacket(); // if there's data available, read a packet
  if (packetSize) {
    discoCount = 0;
    Udp.read(packetBuffer, UDP_TX_PACKET_MAX_SIZE);
    Serial.print("Udp.read: ");
    Serial.println((char *)packetBuffer);
    if(packetBuffer[0]=='1'){
      if(packetBuffer[1]=='1')
        servo1Action(true);
      else if(packetBuffer[1]=='0')
        servo1Action(false);
    }
    Udp.beginPacket(Udp.remoteIP(), Udp.remotePort());  
    Udp.write(*packetBuffer);  // send a reply, to the IP address and port that sent us the packet we received
    Udp.endPacket();
  }
}

