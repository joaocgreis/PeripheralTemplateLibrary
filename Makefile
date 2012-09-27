ifeq ($(TARGET), avr)
MCU = atmega168
TARGET_FLAGS = -mmcu=$(MCU)
endif

ifeq ($(TARGET), msp430)
MCU = msp430g2553
TARGET_FLAGS = -mmcu=$(MCU)
endif

ifeq ($(TARGET), stm32)
LIBOPENCM3_PATH = ../libopencm3
CROSS_COMPILE = arm-linux-gnueabi-
GCC_VER = -4.4
TARGET_INCLUDE = -I$(LIBOPENCM3_PATH)/include
TARGET_FLAGS = -mthumb -mcpu=cortex-m3
TARGET_CFLAGS = $(TARGET_FLAGS) -D__STM32__ -DSTM32F1
TARGET_LDFLAGS = $(TARGET_FLAGS) --static -nostdlib -nostartfiles -Tstm32/f1/stm32f100x6.ld -Wl,--gc-sections \
    -Wl,--build-id=none
LDLIBS = -L$(LIBOPENCM3_PATH)/lib -lopencm3_stm32f1
endif

CROSS_COMPILE ?= $(TARGET)-
GCC_VER ?=
CC = $(CROSS_COMPILE)gcc$(GCC_VER)
CXX = $(CROSS_COMPILE)g++$(GCC_VER)
OBJDUMP = $(CROSS_COMPILE)objdump
OBJCOPY = $(CROSS_COMPILE)objcopy

INCLUDE = -I. $(TARGET_INCLUDE)
TARGET_CFLAGS  ?= $(TARGET_FLAGS)
TARGET_LDFLAGS ?= $(TARGET_FLAGS)
CFLAGS = $(INCLUDE) $(TARGET_CFLAGS) -Os -g
CXXFLAGS = $(CFLAGS) -fno-exceptions
LDFLAGS = $(TARGET_LDFLAGS) -Wl,-Map=$@.map,--cref

ALL = blink blink_timer uart_echo spi i2c_24cxx

.PHONY: $(ALL)

all: $(ALL)

blink: $(TARGET)/blink
blink_timer: $(TARGET)/blink_timer
uart_echo: $(TARGET)/uart_echo
spi: $(TARGET)/spi
i2c_24cxx: $(TARGET)/i2c_24cxx

$(TARGET)/blink: $(TARGET)/blink.o
$(TARGET)/blink.o: blink.cpp

$(TARGET)/blink_timer: $(TARGET)/blink_timer.o
$(TARGET)/blink_timer.o: blink_timer.cpp

$(TARGET)/uart_echo: $(TARGET)/uart_echo.o
$(TARGET)/uart_echo.o: uart_echo.cpp

$(TARGET)/spi: $(TARGET)/spi.o
$(TARGET)/spi.o: spi.cpp

$(TARGET)/i2c_24cxx: $(TARGET)/i2c_24cxx.o
$(TARGET)/i2c_24cxx.o: i2c_24cxx.cpp


$(TARGET)/%.o: %.cpp
	mkdir -p $(TARGET)
	$(CXX) $(CXXFLAGS) -c $^ -o $@

.PRECIOUS: $(TARGET)/%.hex $(TARGET)/%.bin

ifeq ($(TARGET), msp430)
flash-%: $(TARGET)/%
	mspdebug rf2500 "prog $^"
endif

ifeq ($(TARGET), avr)
$(TARGET)/%.hex: $(TARGET)/%
	$(OBJCOPY) -O ihex -R .eeprom $^ $@
	$(OBJCOPY) -j .eeprom --set-section-flags=.eeprom="alloc,load" --change-section-lma .eeprom=0 --no-change-warnings -O ihex $^ $^.eep || exit 0

flash-%: $(TARGET)/%.hex
	avrdude -p m328p -c arduino -P/dev/ttyUSB0 -b57600 -D -Uflash:w:$^
endif

ifeq ($(TARGET), stm32)
$(TARGET)/%.bin: $(TARGET)/%
	$(OBJCOPY) -O binary $^ $@

flash-%: $(TARGET)/%.bin
	st-flash write $^ 0x8000000
endif


disasm-%: $(TARGET)/%
	$(OBJDUMP) -dSt --demangle $^ >$^.disasm

clean:
	rm -f $(TARGET)/*.o
