#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include "Arduino_GFX_Library.h"
#include "pin_config.h"
#include "Secrets.h"

Arduino_DataBus *bus = new Arduino_ESP32QSPI(
    LCD_CS, LCD_SCLK, LCD_SDIO0, LCD_SDIO1, LCD_SDIO2, LCD_SDIO3);
Arduino_CO5300 *gfx = new Arduino_CO5300(
    bus, LCD_RESET, 0, LCD_WIDTH, LCD_HEIGHT, 6, 0, 0, 0);
WebServer server(80);
Arduino_Canvas textCanvas(LCD_WIDTH, 240, gfx);

long consumedCalories = 0;
long targetCalories = 0;
bool hasIntakeState = false;
unsigned long lastWiFiAttempt = 0;

int characterCount(const char *text) {
    int count = 0;
    for (size_t i = 0; text[i] != '\0';) {
        uint8_t first = static_cast<uint8_t>(text[i]);
        i += first < 0x80 ? 1 : (first & 0xE0) == 0xC0 ? 2 : (first & 0xF0) == 0xE0 ? 3 : 4;
        count++;
    }
    return count;
}

void printSpaced(Arduino_GFX &target, const char *text) {
    for (size_t i = 0; text[i] != '\0';) {
        uint8_t first = static_cast<uint8_t>(text[i]);
        size_t length = first < 0x80 ? 1 : (first & 0xE0) == 0xC0 ? 2 : (first & 0xF0) == 0xE0 ? 3 : 4;
        char character[5] = {0};
        memcpy(character, text + i, length);
        target.print(character);
        target.setCursor(target.getCursorX() + 1, target.getCursorY());
        i += length;
    }
}

void drawCentered(const char *text, int y, int size, uint16_t color) {
    gfx->setTextSize(size);
    gfx->setTextColor(color);
    int16_t x1, y1;
    uint16_t width, height;
    gfx->getTextBounds(text, 0, y, &x1, &y1, &width, &height);
    width += max(0, characterCount(text) - 1);
    gfx->setCursor((LCD_WIDTH - width) / 2, y);
    printSpaced(*gfx, text);
}

struct TextMetrics {
    int16_t x;
    int16_t y;
    uint16_t width;
    uint16_t height;
};

TextMetrics measureInk(const char *text, int size) {
    uint16_t *framebuffer = textCanvas.getFramebuffer();
    if (!framebuffer) {
        TextMetrics fallback;
        gfx->setTextSize(size);
        gfx->getTextBounds(text, 0, 0, &fallback.x, &fallback.y, &fallback.width, &fallback.height);
        fallback.width += max(0, characterCount(text) - 1);
        return fallback;
    }

    textCanvas.fillScreen(RGB565_BLACK);
    textCanvas.setTextSize(size);
    textCanvas.setTextColor(RGB565_WHITE);
    textCanvas.setCursor(0, 120);
    printSpaced(textCanvas, text);

    int16_t minX = LCD_WIDTH;
    int16_t minY = 240;
    int16_t maxX = -1;
    int16_t maxY = -1;
    for (int y = 0; y < 240; y++) {
        for (int x = 0; x < LCD_WIDTH; x++) {
            if (framebuffer[y * LCD_WIDTH + x] != RGB565_BLACK) {
                minX = min(minX, static_cast<int16_t>(x));
                minY = min(minY, static_cast<int16_t>(y));
                maxX = max(maxX, static_cast<int16_t>(x));
                maxY = max(maxY, static_cast<int16_t>(y));
            }
        }
    }

    return {
        minX,
        static_cast<int16_t>(minY - 120),
        static_cast<uint16_t>(maxX - minX + 1),
        static_cast<uint16_t>(maxY - minY + 1)
    };
}

void drawCenteredAtTop(const char *text, int top, int size, uint16_t color,
                       TextMetrics metrics) {
    gfx->setTextSize(size);
    gfx->setTextColor(color);
    gfx->setCursor((LCD_WIDTH - static_cast<int>(metrics.width)) / 2 - metrics.x,
                   top - metrics.y);
    printSpaced(*gfx, text);
}

void drawCenteredBoldAtTop(const char *text, int top, int size, uint16_t color,
                           TextMetrics metrics) {
    int x = (LCD_WIDTH - static_cast<int>(metrics.width)) / 2 - metrics.x;
    int y = top - metrics.y;
    gfx->setTextSize(size);
    gfx->setTextColor(color);
    gfx->setCursor(x, y);
    printSpaced(*gfx, text);
    gfx->setCursor(x + 1, y);
    printSpaced(*gfx, text);
    gfx->setCursor(x - 1, y);
    printSpaced(*gfx, text);
}

enum class IntakeLevel { green, yellow, red };

IntakeLevel currentIntakeLevel() {
    if (consumedCalories >= targetCalories) return IntakeLevel::red;
    if (consumedCalories * 100 >= targetCalories * 70) return IntakeLevel::yellow;
    return IntakeLevel::green;
}

uint16_t currentIntakeColor() {
    switch (currentIntakeLevel()) {
        case IntakeLevel::green: return RGB565_GREEN;
        case IntakeLevel::yellow: return RGB565_YELLOW;
        case IntakeLevel::red: return RGB565_RED;
    }
    return RGB565_GREEN;
}

void drawIntakeProgress() {
    static uint16_t *buffer = nullptr;
    size_t pixelCount = LCD_WIDTH * LCD_HEIGHT;
    if (!buffer) {
        buffer = static_cast<uint16_t *>(ps_malloc(pixelCount * sizeof(uint16_t)));
    }
    if (!buffer) {
        Serial.println("Ring buffer allocation failed");
        return;
    }
    memset(buffer, 0, pixelCount * sizeof(uint16_t));

    const int center = 233;
    const int outerSquared = 224 * 224;
    const int innerSquared = 208 * 208;
    uint16_t progressColor = currentIntakeColor();
    long cappedCalories = min(consumedCalories, targetCalories);
    float endAngle = 360.0f * static_cast<float>(cappedCalories) / targetCalories;

    for (int y = 0; y < LCD_HEIGHT; y++) {
        for (int x = 0; x < LCD_WIDTH; x++) {
            int dx = x - center;
            int dy = y - center;
            int distanceSquared = dx * dx + dy * dy;
            if (distanceSquared > outerSquared || distanceSquared < innerSquared) continue;

            float angle = atan2f(dy, dx) * 180.0f / PI + 90.0f;
            if (angle < 0) angle += 360.0f;
            buffer[y * LCD_WIDTH + x] = angle <= endAngle
                ? progressColor : RGB565(32, 40, 32);
        }
    }
    gfx->draw16bitRGBBitmap(0, 0, buffer, LCD_WIDTH, LCD_HEIGHT);
}

void drawScreen() {
    gfx->fillScreen(RGB565_BLACK);

    if (hasIntakeState) {
        long remaining = targetCalories - consumedCalories;
        bool exceeded = remaining < 0;
        long primary = exceeded ? -remaining : remaining;
        const char *title = exceeded ? "今日已经超出" : "今日还可摄入";
        uint16_t titleColor = currentIntakeColor();

        char value[24];
        snprintf(value, sizeof(value), "%ld", primary);

        TextMetrics titleMetrics = measureInk(title, 2);
        TextMetrics valueMetrics = measureInk(value, 9);
        TextMetrics unitMetrics = measureInk("千卡", 2);
        const int gap = 44;
        const int totalHeight = titleMetrics.height + valueMetrics.height + unitMetrics.height + gap * 2;
        const int titleTop = (LCD_HEIGHT - totalHeight) / 2;
        const int valueTop = titleTop + titleMetrics.height + gap;
        const int unitTop = valueTop + valueMetrics.height + gap;

        drawIntakeProgress();
        drawCenteredBoldAtTop(title, titleTop, 2, titleColor, titleMetrics);
        drawCenteredAtTop(value, valueTop, 9, RGB565_WHITE, valueMetrics);
        drawCenteredBoldAtTop("千卡", unitTop, 2, RGB565_WHITE, unitMetrics);
    } else {
        drawCentered("等待手机", 219, 2, RGB565_WHITE);
        drawCentered("拍照后同步", 275, 2, RGB565_LIGHTGREY);
    }

    if (WiFi.status() != WL_CONNECTED) {
        drawCentered("网络已断开", 438, 1, RGB565_RED);
    }
}

bool parseInteger(const String &value, long minimum, long &result) {
    if (value.isEmpty()) return false;
    for (size_t i = 0; i < value.length(); i++) {
        if (!isDigit(value.charAt(i))) return false;
    }
    char *end = nullptr;
    long parsed = strtol(value.c_str(), &end, 10);
    if (end == nullptr || *end != '\0' || parsed < minimum || parsed > 1000000) {
        return false;
    }
    result = parsed;
    return true;
}

void handleUpdate() {
    long newConsumed = 0;
    long newTarget = 0;
    if (!parseInteger(server.arg("kcal"), 0, newConsumed) ||
        !parseInteger(server.arg("target"), 1, newTarget)) {
        server.send(400, "text/plain", "Expected non-negative kcal and positive target");
        return;
    }

    consumedCalories = newConsumed;
    targetCalories = newTarget;
    hasIntakeState = true;
    drawScreen();
    server.send(200, "application/json", "{\"ok\":true}");
}

void handleHealth() {
    String body = "{\"ok\":true,\"kcal\":" + String(consumedCalories) +
                  ",\"target\":" + String(targetCalories) + "}";
    server.send(200, "application/json", body);
}

void connectWiFi() {
    lastWiFiAttempt = millis();
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    drawScreen();

    unsigned long started = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - started < 15000) {
        delay(250);
    }
    drawScreen();
}

void setup() {
    Serial.begin(115200);
    Wire.begin(IIC_SDA, IIC_SCL);
    if (!gfx->begin()) {
        Serial.println("Display initialization failed");
    }
    gfx->setBrightness(128);
    gfx->setFont(u8g2_font_unifont_h_chinese);
    gfx->setUTF8Print(true);
    if (!textCanvas.begin(GFX_SKIP_OUTPUT_BEGIN)) {
        Serial.println("Text measurement canvas initialization failed");
    }
    textCanvas.setFont(u8g2_font_unifont_h_chinese);
    textCanvas.setUTF8Print(true);

    server.on("/health", HTTP_GET, handleHealth);
    server.on("/update", HTTP_POST, handleUpdate);
    server.onNotFound([]() { server.send(404, "text/plain", "Not found"); });
    WiFi.onEvent([](WiFiEvent_t event, WiFiEventInfo_t info) {
        if (event == ARDUINO_EVENT_WIFI_STA_DISCONNECTED) {
            Serial.printf("Wi-Fi disconnect reason: %d\n", info.wifi_sta_disconnected.reason);
        }
    });

    connectWiFi();
    server.begin();
    if (WiFi.status() == WL_CONNECTED) {
        Serial.print("ESP32 IP: ");
        Serial.println(WiFi.localIP());
    } else {
        Serial.println("Wi-Fi connection failed");
    }
}

void loop() {
    server.handleClient();
    if (WiFi.status() != WL_CONNECTED && millis() - lastWiFiAttempt > 30000) {
        connectWiFi();
    }
    delay(2);
}
