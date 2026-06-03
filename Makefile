# ══════════════════════════════════════════════════════════════════════════════
#  Makefile  –  C++ + raylib cross-platform build system
#  Targets:  make          → debug build
#            make release  → optimised release build
#            make run      → build + run
#            make clean    → remove build artefacts
#            make info     → print detected config
#
#  Layout expected:
#    src/         *.cpp / *.cc source files (recursive)
#    include/     project headers
#    build/       generated object files   (auto-created)
#    bin/         final executable         (auto-created)
# ══════════════════════════════════════════════════════════════════════════════

# ── project ────────────────────────────────────────────────────────────────────
TARGET      := game
SRC_DIR     := src
INC_DIR     := include
BUILD_DIR   := build
BIN_DIR     := bin

# ── compiler ───────────────────────────────────────────────────────────────────
CXX         := g++
CXXSTD      := -std=c++17
WARN        := -Wall -Wextra -Wno-missing-field-initializers

# ── platform detection ────────────────────────────────────────────────────────
ifeq ($(OS),Windows_NT)
    PLATFORM   := WINDOWS
    EXE        := $(BIN_DIR)/$(TARGET).exe
    # Common raylib install paths on Windows (MinGW / w64devkit)
    RAYLIB_PATH ?= C:/raylib/raylib
    RL_INC     := $(RAYLIB_PATH)/src
    RL_LIB     := $(RAYLIB_PATH)/src
    LIBS       := -L$(RL_LIB) -lraylib -lopengl32 -lgdi32 -lwinmm
    RM         := del /Q
    MKDIR      := mkdir
else
    UNAME := $(shell uname -s)
    ifeq ($(UNAME),Darwin)
        PLATFORM   := MACOS
        EXE        := $(BIN_DIR)/$(TARGET)
        # Homebrew default; override with: make RAYLIB_PATH=/custom/path
        RAYLIB_PATH ?= $(shell brew --prefix raylib 2>/dev/null || echo /usr/local)
        RL_INC     := $(RAYLIB_PATH)/include
        RL_LIB     := $(RAYLIB_PATH)/lib
        LIBS       := -L$(RL_LIB) -lraylib \
                      -framework CoreVideo -framework IOKit \
                      -framework Cocoa -framework GLUT -framework OpenGL
        RM         := rm -f
        MKDIR      := mkdir -p
    else
        PLATFORM   := LINUX
        EXE        := $(BIN_DIR)/$(TARGET)
        # pkg-config first, then fall back to a manual path
        RL_INC     ?= $(shell pkg-config --cflags-only-I raylib 2>/dev/null | sed 's/-I//' || echo /usr/local/include)
        RL_LIB_DIR ?= $(shell pkg-config --libs-only-L   raylib 2>/dev/null | sed 's/-L//' || echo /usr/local/lib)
        LIBS       := -L$(RL_LIB_DIR) -lraylib -lGL -lm -lpthread -ldl -lrt -lX11
        RM         := rm -f
        MKDIR      := mkdir -p
    endif
endif

# ── source discovery ──────────────────────────────────────────────────────────
SRCS := $(shell find $(SRC_DIR) -name '*.cpp' -o -name '*.cc' 2>/dev/null)
OBJS := $(patsubst $(SRC_DIR)/%,$(BUILD_DIR)/%,$(SRCS:.cpp=.o))
OBJS := $(OBJS:.cc=.o)
DEPS := $(OBJS:.o=.d)

# ── flags ─────────────────────────────────────────────────────────────────────
INCLUDES := -I$(INC_DIR) -I$(RL_INC)

DEBUG_FLAGS   := -g3 -O0 -DDEBUG
RELEASE_FLAGS := -O2 -DNDEBUG -flto

# Default: debug
BUILD_TYPE ?= debug
ifeq ($(BUILD_TYPE),release)
    EXTRA_FLAGS := $(RELEASE_FLAGS)
else
    EXTRA_FLAGS := $(DEBUG_FLAGS)
endif

CXXFLAGS := $(CXXSTD) $(WARN) $(INCLUDES) $(EXTRA_FLAGS)

# ── rules ─────────────────────────────────────────────────────────────────────
.PHONY: all release run clean info

all: $(EXE)

release:
	$(MAKE) BUILD_TYPE=release

run: all
	./$(EXE)

# Link
$(EXE): $(OBJS) | $(BIN_DIR)
	@echo "[LINK] $@"
	$(CXX) $(CXXFLAGS) $^ -o $@ $(LIBS)
	@echo "→ Built: $@  ($(BUILD_TYPE))"

# Compile (with automatic dependency generation)
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cpp | $(BUILD_DIR)
	@echo "[CXX]  $<"
	@$(MKDIR) $(dir $@)
	$(CXX) $(CXXFLAGS) -MMD -MP -c $< -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cc | $(BUILD_DIR)
	@echo "[CXX]  $<"
	@$(MKDIR) $(dir $@)
	$(CXX) $(CXXFLAGS) -MMD -MP -c $< -o $@

# Directories
$(BUILD_DIR):
	$(MKDIR) $(BUILD_DIR)

$(BIN_DIR):
	$(MKDIR) $(BIN_DIR)

clean:
	$(RM) -r $(BUILD_DIR) $(BIN_DIR)

info:
	@echo "Platform : $(PLATFORM)"
	@echo "Target   : $(EXE)"
	@echo "CXX      : $(CXX)  ($(shell $(CXX) --version | head -1))"
	@echo "RL inc   : $(RL_INC)"
	@echo "Sources  : $(SRCS)"
	@echo "Build    : $(BUILD_TYPE)"

# Include auto-generated dependency files (silently ignore if missing)
-include $(DEPS)
