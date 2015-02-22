#include <Arduino.h>

#define PIN_LED 13 // Surface-mount LED on the UNO

void loop()
{
    digitalWrite(PIN_LED, HIGH);
    Serial.println("HIGH");
    delay(1000);
    digitalWrite(PIN_LED, LOW);
    Serial.println("LOW");
    delay(1000);
}

int main(void)
{
    init();
    
    Serial.begin(9600);
    pinMode(PIN_LED, OUTPUT);
    
    for (;;) {
        loop();
    }
        
    return 0;
}