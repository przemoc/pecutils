# Copyright (C) 2014 Przemyslaw Pawelczyk <przemoc@gmail.com>

BINS := inpuho

inpuho_SRCS := \
 inpuho.c

### Directories
PROJ_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
SRCS_DIR := $(PROJ_DIR)src/
OBJS_DIR := $(PROJ_DIR)obj/
BINS_DIR := $(PROJ_DIR)bin/

SDEP := Makefile.dep

# when building from project tree, then always use the same output layout
# otherwise use current working directory
ifneq (,$(findstring ^$(realpath $(PROJ_DIR)),^$(realpath ./)))
	SDEP := $(PROJ_DIR)$(SDEP)
else
	OBJS_DIR := ./obj/
	BINS_DIR := ./bin/
endif

### Default target
all: $(addprefix $(BINS_DIR),$(BINS))

### Flags
MUSTHAVE_FLAGS := -std=c99 -D_XOPEN_SOURCE=700 -Wall
OPTIONAL_FLAGS := -Werror -Wextra -Os

### Install paths
PREFIX := /usr/local
EPREFIX := $(PREFIX)
BINDIR := $(EPREFIX)/bin


### Phony targets
.PHONY: all clean distclean dep install strip uninstall

### Install tools
INSTALL := install
INSTALL_EXEC := $(INSTALL) -m 0755

### Build tools
DEFCC := gcc
ifeq ($(origin CC),default)
CC := $(DEFCC)
endif
ifneq ($(origin CC),environment)
CC := $(CROSS_COMPILE)$(CC)
endif
ifneq ($(origin CCLD),environment)
CCLD := $(CC)
endif
ifneq ($(origin STRIP),environment)
STRIP := $(CROSS_COMPILE)strip
endif
CC_PARAMS = $(CFLAGS) $(CPPFLAGS) $(TARGET_ARCH)

### Helpers
comma := ,

### Final flags
ifneq ($(origin CFLAGS),environment)
CFLAGS := $(OPTIONAL_FLAGS)
endif
override CFLAGS += $(MUSTHAVE_FLAGS)
override LDFLAGS := $(subst -Wl$(comma),,$(LDFLAGS))
CCLDFLAGS := $(addprefix -Wl$(comma),$(LDFLAGS))

vpath %.c $(SRCS_DIR)

### Support for hiding command-line
V := 0
HIDE_0 := @
HIDE_1 :=
HIDE := $(HIDE_$(V))

### Rules for directories

$(sort $(OBJS_DIR) $(BINS_DIR)):
	@mkdir -p $@

### Templated rules

define BIN_template

$(1)_OBJS := $$($(1)_SRCS:.c=.o)

$(BINS_DIR)$(1): $$(addprefix $$(OBJS_DIR),$$($(1)_OBJS)) $$(SDEP) | $$(BINS_DIR)
	@echo "        CCLD    $$@"
	$$(HIDE)$$(CCLD) $$(CCLDFLAGS) $$(TARGET_ARCH) -o $$@ $$(filter %.o,$$^) \
	                 -Wl,-Bstatic $$($(1)_SLIBS) -Wl,-Bdynamic $$($(1)_DLIBS)

SRCS += $$($(1)_SRCS)
OBJS += $$($(1)_OBJS)

endef

$(foreach BIN,$(BINS),$(eval $(call BIN_template,$(BIN))))

### Rules for normal targets

$(OBJS_DIR)%.o: %.c
	@echo "        CC      $@"
	$(HIDE)mkdir -p $(dir $@)
	$(HIDE)$(CC) $(CC_PARAMS) -c -o $@ $<

$(SDEP): SRCS_PATH := $(SRCS_DIR)
$(SDEP): SRCS_DIR := ./
$(SDEP): $(SRCS) $(PROJ_DIR)Makefile
	@echo "        DEPS";
	$(HIDE)echo "# This file is automatically (re)generated by make." >$(SDEP)
	$(HIDE)echo >>$(SDEP)
	$(HIDE)(cd "$(SRCS_PATH)" && for FILE in $(SRCS); do \
		$(CC) $(CFLAGS) -MT "\$$(OBJS_DIR)$${FILE%.c}.o" -MM "$$FILE"; \
	done) >>$(SDEP)

### Rules for phony targets

clean:
	@echo "        CLEAN"
	$(HIDE)$(RM) $(addprefix $(BINS_DIR),$(BINS)) $(addprefix $(OBJS_DIR),$(OBJS)) $(SDEP)

distclean: clean
	$(HIDE)(rmdir $(OBJS_DIR) $(BINS_DIR) 2>/dev/null ; exit 0)

dep: $(SDEP)

strip: $(addprefix $(BINS_DIR),$(BINS))
	@echo "        STRIP   $^"
	$(HIDE)$(STRIP) $^

install: $(addprefix $(BINS_DIR),$(BINS))
	@echo "        INSTALL $^"
	$(HIDE)$(INSTALL) -d $(DESTDIR)$(BINDIR)
	$(HIDE)$(INSTALL_EXEC) $(addprefix $(BINS_DIR),$(BINS)) $(DESTDIR)$(BINDIR)/

uninstall:
	@echo "        UNINST  $^"
	$(HIDE)$(RM) $(addprefix $(DESTDIR)$(BINDIR)/,$(BINS))

### Dependencies
ifneq ($(MAKECMDGOALS),distclean)
ifneq ($(MAKECMDGOALS),clean)
-include $(SDEP)
endif
endif
