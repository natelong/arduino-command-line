# Based largely on Maik Schmidt's work here:
# https://github.com/maik/pragpub/blob/53abf772e5525fc62ef3c96b798d9cdb331f8a26/hacking_arduino/part1/Makefile.master

# Build Settings
ARDUINO_DIR = ../arduino-1.0.6
BUILD_DIR   = build
SKETCH      = demo

# Board Settings
# Board info: ./arduino-xxx/hardware/arduino/boards.txt 
# Programmer info: ./arduino-xxx/hardware/arduino/boards.txt
ARD_REV      = 0022
BOARD        = uno
PORT         = COM3
MCU          = atmega328p
F_CPU        = 16000000L
UPLOAD_SPEED = 115200
PROGRAMMER   = arduino

###############################################################################
###############################################################################
# No Need to edit below this line
###############################################################################
###############################################################################

# Serial Monitor Config
MONITOR = ./tools/putty/putty.exe
BAUD    = 9600

# Arduino Environment
AVR_HOME     = $(ARDUINO_DIR)/hardware/tools/avr
ARD_BIN      = $(AVR_HOME)/bin
AVRDUDE      = $(ARD_BIN)/avrdude
AVRDUDE_CONF = $(AVR_HOME)/etc/avrdude.conf

# ARD Settings
ARD_SRC_DIR = $(ARDUINO_DIR)/hardware/arduino/cores/arduino
ARD_MAIN    = $(ARD_SRC_DIR)/main.cpp

# Build Tools
CC      = $(ARD_BIN)/avr-gcc
CXX     = $(ARD_BIN)/avr-g++
OBJCOPY = $(ARD_BIN)/avr-objcopy
OBJDUMP = $(ARD_BIN)/avr-objdump
AR      = $(ARD_BIN)/avr-ar
SIZE    = $(ARD_BIN)/avr-size
NM      = $(ARD_BIN)/avr-nm

# General Aliases
MKDIR   = mkdir -p
RM      = rm -rf
LN      = ln -f

INC_FLAGS    = -I$(ARD_SRC_DIR) -I$(ARD_SRC_DIR)/../../variants/standard
ARD_FLAGS    = -mmcu=$(MCU) -DF_CPU=$(F_CPU) -DARDUINO=$(ARD_REV)
SHARED_FLAGS = -Wall -Wextra -Wundef -Wno-unused-parameter
C_FLAGS      = $(SHARED_FLAGS) -std=gnu99
CXX_FLAGS    = $(SHARED_FLAGS)

OPT_FLAGS = \
     -Os -funsigned-char -funsigned-bitfields -fpack-struct -fshort-enums \
    -ffunction-sections -fdata-sections -Wl,--gc-sections,--relax \
    -fno-inline-small-functions -fno-tree-scev-cprop -fno-exceptions \
    -ffreestanding -mcall-prologues

# Build Parameters
IMAGE       = $(BUILD_DIR)/$(SKETCH)
ARD_C_SRC   = $(wildcard $(ARD_SRC_DIR)/*.c)
ARD_CXX_SRC = $(wildcard $(ARD_SRC_DIR)/*.cpp)
ARD_CXX_SRC := $(filter-out $(ARD_SRC_DIR)/main.cpp, $(ARD_CXX_SRC))
ARD_C_OBJ   = $(patsubst %.c,%.o,$(notdir $(ARD_C_SRC)))
ARD_CXX_OBJ = $(patsubst %.cpp,%.o,$(notdir $(ARD_CXX_SRC)))
ARD_LIB     = arduino
ARD_AR      = $(BUILD_DIR)/lib$(ARD_LIB).a
ARD_AR_OBJ  = $(ARD_AR)($(ARD_C_OBJ) $(ARD_CXX_OBJ))
ARD_LD_FLAG = -l$(ARD_LIB)

$(ARD_AR)(%.o): CXX_FLAGS += -w

# C and C++ source.
SKT_C_SRC   = $(wildcard *.c)
SKT_CXX_SRC = $(wildcard *.cpp)

ifneq "$(strip $(SKT_C_SRC) $(SKT_CXX_SRC))" ""
	SKT_C_OBJ   = $(patsubst %.c,%.o,$(SKT_C_SRC))
	SKT_CXX_OBJ = $(patsubst %.cpp,%.o,$(SKT_CXX_SRC))
	SKT_LIB     = sketch
	SKT_AR      = $(BUILD_DIR)/lib$(SKT_LIB).a
	SKT_AR_OBJ  = $(SKT_AR)/($(SKT_C_OBJ) $(SKT_CXX_OBJ))
	SKT_LD_FLAG = -l$(SKT_LIB)
endif

# Definitions.
define run-cc
	@$(CC) $(ARD_FLAGS) $(INC_FLAGS) -M -MT '$@($%)' -MF $@_$*.dep $<
	@$(CC) -c $(C_FLAGS) $(OPT_FLAGS) $(ARD_FLAGS) $(INC_FLAGS) \
	    $< -o $(BUILD_DIR)/$%
	@$(AR) rc $@ $(BUILD_DIR)/$%
	@$(RM) $(BUILD_DIR)/$%
endef

define run-cxx
	@$(CXX) $(ARD_FLAGS) $(INC_FLAGS) -M -MT '$@($%)' -MF $@_$*.dep $<
	@$(CXX) -c $(CXX_FLAGS) $(OPT_FLAGS) $(ARD_FLAGS) $(INC_FLAGS) \
	    $< -o $(BUILD_DIR)/$%
	@$(AR) rc $@ $(BUILD_DIR)/$%
	@$(RM) $(BUILD_DIR)/$%
endef

# Rules.
.PHONY: all clean upload
all : $(BUILD_DIR) $(IMAGE).hex

clean:
	@echo $(ARD_CXX_TARG)
	@$(RM) $(BUILD_DIR)

$(BUILD_DIR):
	@$(MKDIR) $@

(%.o): $(ARD_SRC_DIR)/%.c
	$(run-cc)

(%.o): $(ARD_SRC_DIR)/%.cpp
	$(run-cxx)

(%.o): %.c
	$(run-cc)

(%.o): %.cpp
	$(run-cxx)

$(BUILD_DIR)/%.d: %.c
	$(run-cc-d)

$(BUILD_DIR)/%.d: %.cpp
	$(run-cxx-d)

$(IMAGE).hex: $(ARD_AR_OBJ) $(LIB_AR_OBJ) $(SKT_AR_OBJ)
	@$(CC) $(CXX_FLAGS) $(OPT_FLAGS) $(ARD_FLAGS) -L$(BUILD_DIR) \
	    $(SKT_LD_FLAG) $(ARD_LD_FLAG) -lm \
	    -o $(IMAGE).elf
	@$(OBJCOPY) -O ihex -j .eeprom --set-section-flags=.eeprom=alloc,load \
	    --no-change-warnings --change-section-lma .eeprom=0 $(IMAGE).elf \
	    $(IMAGE).eep
	@$(OBJCOPY) -O ihex -R .eeprom $(IMAGE).elf $(IMAGE).hex
	$(SIZE) $(IMAGE).hex

upload: all
	@$(AVRDUDE) -V -C $(AVRDUDE_CONF) -p $(MCU) -c $(PROGRAMMER) \
	  -P $(PORT) -b $(UPLOAD_SPEED) -D -U flash:w:$(IMAGE).hex:i

monitor:
	@$(MONITOR) -serial -sercfg $(BAUD) $(PORT)