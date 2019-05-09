#include <ESP8266WiFi.h>
#include <ESP8266WiFiAP.h>
#include <ESP8266WiFiGeneric.h>
#include <ESP8266WiFiMulti.h>
#include <ESP8266WiFiScan.h>
#include <ESP8266WiFiSTA.h>
#include <ESP8266WiFiType.h>
#include <WiFiClient.h>
#include <WiFiClientSecure.h>
#include <WiFiServer.h>
#include <WiFiUdp.h>
#include <ESP8266WiFi.h>
#include <DNSServer.h> 
#include <ESP8266WebServer.h>
#include <WiFiUdp.h>
#include <Servo.h>
#include <Ticker.h>

#ifndef STASSID
#define STASSID "DISCO-027361"
#define STAPSK  ""
#endif
#define SUBTITLE "PARROT DISCO" // Cool subtitle

//#define APSSID "ESP8266-IOT" // SSID & Title
//#define APPASSWORD "" // Blank password = Open AP

const char* ssid     = STASSID;
const char* password = STAPSK;
const byte HTTP_CODE = 200;
const byte TICK_TIMER = 1000;
IPAddress discozip (192, 168, 42, 1);
//Static IP address configuration
//IPAddress staticIP(192, 168, 42, 8); //ESP static ip
//IPAddress gateway(192, 168, 42, 1);   //IP Address of your WiFi Router (Gateway)
//IPAddress subnet(255, 255, 255, 0);  //Subnet mask
//IPAddress dns(8, 8, 8, 8);  //DNS

unsigned long bootTime=0, lastActivity=0, lastTick=0, tickCtr=0;
DNSServer dnsServer; ESP8266WebServer webServer(80);

Servo servo1;
const int servo1Pin = 2; //D4

Ticker discoTicker;
int discoCount = 0;

unsigned int localPort = 8888;      // local port to listen on
char packetBuffer[UDP_TX_PACKET_MAX_SIZE]; //buffer to hold incoming packet,
WiFiUDP Udp;

String input(String argName) {
  String a=webServer.arg(argName);
  a.replace("<","&lt;");a.replace(">","&gt;");
  a.substring(0,200); return a; }

String footer() { return "<footer>"
  "<div class=\"footer\""
  " <p>UDP server is available on port 8888</p>"
  "</div>"
  "</footer>";
}

String header() {
  String a = String(STASSID);
  String CSS = "article { background: #f2f2f2; padding: 1.3em; }" 
  "body { color: #333; font-family: Century Gothic, sans-serif; font-size: 18px; line-height: 24px; margin: 0; padding: 0; }"
  "div { padding: 0.35em; }"
  "h1 { margin: 0.5em 0 0 0; padding: 0.5em; }"
  "input { border-radius: 0; border: 1px solid #555555; }"
  "label { color: #333; display: block; font-style: italic; font-weight: bold; }"
  "nav { background: #0066ff; color: #fff; display: block; font-size: 1.3em; padding: 1em; }"
  "nav b { display: block; font-size: 1.5em; margin-bottom: 0.5em; } "
  "textarea { width: 100%; }"
  ".button {"
  "background-color: #4CAF50;"
  "border: 1px solid black;"
  "border-radius: 6px;"
  "color: white;"
  "padding: 15px 32px;"
  "text-align: center;"
  "text-decoration: none;"
  "display: inline-block;"
  "font-size: 16px;"
  "margin: 4px 2px;"
  "cursor: pointer;"
  "}"
  ".buttonb { background-color: #555555; }"
  ".footer {"
  "position: fixed;"
  "left: 0;"
  "bottom: 0;"
  "width: 100%;"
  "background-color: #0066ff;"
  "color: white;"
  "text-align: center;"
  "font-family: \"Verdana\", Sans, serif;"
  "border-radius: 0px;"
  "height: 25px"
  "}";
  String h = "<!DOCTYPE html><html>"
    "<head><title>"+a+" :: "+SUBTITLE+"</title>"
    "<meta name=viewport content=\"width=device-width,initial-scale=1\">"
    "<style>"+CSS+"</style></head>"
    "<body><nav><b>"+a+"</b> "+SUBTITLE+"</nav><br>";
  return h; }

String index() {
  return header() +
  // 1st ONE:
  +"<center><table><tr><th><div><form action=/1ON method=post>"+
  +"<input type=submit class=\"button\" value=\"1 ON\"></form></center></th>"+
  +"<th><center><div><form action=/1OFF method=post>"+
  +"<input type=submit class=\"button buttonb\" value=\"1 OFF\"></form></center></th></tr>"+
  // 2nd ONE:
  + "<table><tr><th><center><div><form action=/2ON method=post>"+
  +"<input type=submit class=\"button\" value=\"2 ON\"></form></center></th>"+
  +"<th><center><div><form action=/2OFF method=post>"+
  +"<input type=submit class=\"button buttonb\" value=\"2 OFF\"></form></center></th></tr>"+
  // 3rd ONE:
  + "<table><tr><th><center><div><form action=/3ON method=post>"+
  +"<input type=submit class=\"button\" value=\"3 ON\"></form></center></th>"+
  +"<th><center><div><form action=/3OFF method=post>"+
  +"<input type=submit class=\"button buttonb\" value=\"3 OFF\"></form></th></tr></center>"+
  // 4th ONE:
  + "<table><tr><th><center><div><form action=/4ON method=post>"+
  +"<input type=submit class=\"button\" value=\"4 ON\"></form></center></th>"+
  +"<th><center><div><form action=/4OFF method=post>"+
  +"<input type=submit class=\"button buttonb\" value=\"4 OFF\"></form></th></tr></table></center><br>" + footer();
}


void setup() {
  bootTime = lastActivity = millis();
  
  Serial.begin(115200);
  delay(10);
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(ssid);

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  //WiFi.config(staticIP, subnet, gateway, dns);
  //WiFi.mode(WIFI_AP);
  //WiFi.softAPConfig(APIP, APIP, IPAddress(255, 255, 255, 0));
  //WiFi.softAP(APSSID, APPASSWORD);

  webServer.on("/1ON",[]() { servo1Action(true); webServer.send(HTTP_CODE, "text/html", index()); });
  //webServer.on("/2ON",[]() { digitalWrite(14, HIGH); webServer.send(HTTP_CODE, "text/html", index()); });
  //webServer.on("/3ON",[]() { digitalWrite(12, HIGH); webServer.send(HTTP_CODE, "text/html", index()); });
  //webServer.on("/4ON",[]() { digitalWrite(15, HIGH); webServer.send(HTTP_CODE, "text/html", index()); });
  webServer.on("/1OFF",[]() {servo1Action(false); webServer.send(HTTP_CODE, "text/html", index()); });
  //webServer.on("/2OFF",[]() { digitalWrite(14, LOW); webServer.send(HTTP_CODE, "text/html", index()); });
  //webServer.on("/3OFF",[]() { digitalWrite(12, LOW); webServer.send(HTTP_CODE, "text/html", index()); });
  //webServer.on("/4OFF",[]() { digitalWrite(15, LOW); webServer.send(HTTP_CODE, "text/html", index()); });
  webServer.onNotFound([]() { lastActivity=millis(); webServer.send(HTTP_CODE, "text/html", index()); });
  webServer.begin();
  
  Udp.begin(localPort);
  
  servo1.attach(servo1Pin);  //D4
  servo1.write(35);

  pinMode(LED_BUILTIN, OUTPUT);     // Initialize the LED_BUILTIN pin as an output
  //pinMode(14, OUTPUT);
  //pinMode(12, OUTPUT);
  //pinMode(15, OUTPUT);

  discoTicker.attach(0.8, discoCounter);
}

void discoCounter() {
  discoCount++;
  if(discoCount >= 2)
    servo1Action(true);
}

void servo1Action(bool action) {
  if(action){
    servo1.write(140);
    digitalWrite(LED_BUILTIN, LOW);
  }
  else{
    servo1.write(35);
    digitalWrite(LED_BUILTIN, HIGH);
  }
}

void loop() { 
  if ((millis()-lastTick)>TICK_TIMER) {lastTick=millis();} 
  dnsServer.processNextRequest(); 
  webServer.handleClient(); 

  int packetSize = Udp.parsePacket(); // if there's data available, read a packet
  if (packetSize) {
    discoCount = 0;
    
    Udp.read(packetBuffer, UDP_TX_PACKET_MAX_SIZE);
    if(packetBuffer[0]=='1'){
      if(packetBuffer[1]=='1')
        servo1Action(true);
      else if(packetBuffer[1]=='0')
        servo1Action(false);
    }
    
    Udp.beginPacket(Udp.remoteIP(), Udp.remotePort());  
    Udp.write(packetBuffer);  // send a reply, to the IP address and port that sent us the packet we received
    Udp.endPacket();
  }
}

