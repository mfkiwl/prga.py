# Automatically generated by PRGA Verilog-to-Bitstream Flow Generator
# ----------------------------------------------------------------------------
# -- Binaries ----------------------------------------------------------------
# ----------------------------------------------------------------------------
# Use `make PYTHON=xxx` to replace these binaries if needed
PYTHON ?= python
YOSYS ?= yosys
VPR ?= vpr
GENFASM ?= genfasm

# ----------------------------------------------------------------------------
# -- Make Config -------------------------------------------------------------
# ----------------------------------------------------------------------------
SHELL = /bin/bash
.SHELLFLAGS = -o pipefail -c

# ----------------------------------------------------------------------------
# -- Inputs ------------------------------------------------------------------
# ----------------------------------------------------------------------------
# ** PRGA Database **
SUMMARY := {{ summary }}

# ** Target Design **
DESIGN := {{ design.name }}

DESIGN_SRCS :=
{%- for src in design.sources %}
DESIGN_SRCS += {{ abspath(src) }}
{%- endfor %}

DESIGN_INCS :=
{%- for dir_ in design.includes|default([]) %}
DESIGN_INCS += $(shell find -type f {{ abspath(dir_) }})
{%- endfor %}

# ** SYN **
SYN_SCRIPT := {{ syn.design }}

# ** PAR **
VPR_CHAN_WIDTH := {{ vpr.channel_width }}
VPR_ARCHDEF := {{ vpr.archdef }}
VPR_RRGRAPH := {{ vpr.rrgraph }}
VPR_IOCONSTRAINTS := {{ abspath(constraints.io) }}

# ----------------------------------------------------------------------------
# -- Outputs -----------------------------------------------------------------
# ----------------------------------------------------------------------------
# ** SYN **
SYN_EBLIF := syn.eblif
{%- if tests is defined %}
SYN_V := postsyn.v
SYN_RESULT := $(SYN_EBLIF) $(SYN_V)
{%- else %}
SYN_RESULT := $(SYN_EBLIF)
{%- endif %}
SYN_LOG := syn.log

# ** PACK **
PACK_RESULT := pack.out
PACK_LOG := pack.log

# ** IO Constraints **
IOPLAN_RESULT := ioplan.out
IOPLAN_LOG := ioplan.log

# ** PLACE **
PLACE_RESULT := place.out
PLACE_LOG := place.log

# ** ROUTE **
ROUTE_RESULT := route.out
ROUTE_LOG := route.log

# ** FASM **
FASM_RESULT := fasm.out
FASM_LOG := fasm.log

# ** BITGEN **
BITGEN_RESULT := bitgen.out
BITGEN_LOG := bitgen.log

# ----------------------------------------------------------------------------
# -- Aggregated Variables ----------------------------------------------------
# ----------------------------------------------------------------------------
OUTPUTS := $(SYN_RESULT) $(PACK_RESULT) $(IOPLAN_RESULT) $(PLACE_RESULT) $(ROUTE_RESULT) $(FASM_RESULT) $(BITGEN_RESULT)
LOGS := $(SYN_LOG) $(PACK_LOG) $(IOPLAN_LOG) $(PLACE_LOG) $(ROUTE_LOG) $(FASM_LOG) $(BITGEN_LOG)
JUNKS := vpr_stdout.log *.rpt pack.out.post_routing

# ----------------------------------------------------------------------------
# -- Phony Rules -------------------------------------------------------------
# ----------------------------------------------------------------------------
.PHONY: all syn pack ioplan place route fasm bitgen disp clean

all: $(BITGEN_RESULT)

syn: $(SYN_RESULT)

pack: $(PACK_RESULT)

ioplan: $(IOPLAN_RESULT)

place: $(PLACE_RESULT)

route: $(ROUTE_RESULT)

fasm: $(FASM_RESULT)

bitgen: $(BITGEN_RESULT)

disp: $(VPR_ARCHDEF) $(VPR_RRGRAPH) $(SYN_EBLIF) $(PACK_RESULT) $(PLACE_RESULT) $(ROUTE_RESULT)
	$(VPR) $(VPR_ARCHDEF) $(SYN_EBLIF) --circuit_format eblif --constant_net_method route \
		--net_file $(PACK_RESULT) --place_file $(PLACE_RESULT) --route_file $(ROUTE_RESULT) \
		--analysis --disp on --route_chan_width $(VPR_CHAN_WIDTH) --read_rr_graph $(VPR_RRGRAPH)

clean:
	rm -rf $(OUTPUTS) $(LOGS) $(JUNKS)

# ----------------------------------------------------------------------------
# -- Regular Rules -----------------------------------------------------------
# ----------------------------------------------------------------------------
$(SYN_RESULT): $(DESIGN_SRCS) $(DESIGN_INCS) $(SYN_SCRIPT)
	$(YOSYS) -c $(SYN_SCRIPT) \
		| tee $(SYN_LOG)

$(PACK_RESULT): $(VPR_ARCHDEF) $(SYN_EBLIF)
	$(VPR) $^ --circuit_format eblif --pack --net_file $@ --constant_net_method route \
		| tee $(PACK_LOG)

$(IOPLAN_RESULT): $(SUMMARY) $(SYN_EBLIF) $(VPR_IOCONSTRAINTS)
ifeq ($(VPR_IOCONSTRAINTS),)
	$(PYTHON) -O -m prga.tools.ioplan -c $(SUMMARY) -d $(SYN_EBLIF) -o $@ \
		| tee $(IOPLAN_LOG)
else
	$(PYTHON) -O -m prga.tools.ioplan -c $(SUMMARY) -d $(SYN_EBLIF) -o $@ -f $(VPR_IOCONSTRAINTS) \
		| tee $(IOPLAN_LOG)
endif

$(PLACE_RESULT): $(VPR_ARCHDEF) $(SYN_EBLIF) $(PACK_RESULT) $(IOPLAN_RESULT)
	$(VPR) $(VPR_ARCHDEF) $(SYN_EBLIF) --circuit_format eblif --constant_net_method route \
		--net_file $(PACK_RESULT) \
		--place --place_file $@ --fix_clusters $(IOPLAN_RESULT) \
		--place_delay_model delta_override --place_chan_width $(VPR_CHAN_WIDTH) \
		| tee $(PLACE_LOG)

$(ROUTE_RESULT): $(VPR_ARCHDEF) $(VPR_RRGRAPH) $(SYN_EBLIF) $(PACK_RESULT) $(PLACE_RESULT)
	$(VPR) $(VPR_ARCHDEF) $(SYN_EBLIF) --circuit_format eblif --constant_net_method route \
		--net_file $(PACK_RESULT) --place_file $(PLACE_RESULT) \
		--route --route_file $@ --route_chan_width $(VPR_CHAN_WIDTH) --read_rr_graph $(VPR_RRGRAPH) \
		| tee $(ROUTE_LOG)

$(FASM_RESULT): $(VPR_ARCHDEF) $(VPR_RRGRAPH) $(SYN_EBLIF) $(PACK_RESULT) $(PLACE_RESULT) $(ROUTE_RESULT)
	$(GENFASM) $(VPR_ARCHDEF) $(DESIGN) \
		--circuit_file $(SYN_EBLIF) --circuit_format eblif \
		--net_file $(PACK_RESULT) --place_file $(PLACE_RESULT) --route_file $(ROUTE_RESULT) \
		--analysis --route_chan_width $(VPR_CHAN_WIDTH) --read_rr_graph $(VPR_RRGRAPH) \
		| tee $(FASM_LOG)
	mv $(DESIGN).fasm $@

$(BITGEN_RESULT): $(SUMMARY) $(FASM_RESULT)
	$(PYTHON) -O -m prga.tools.bitgen -c $(SUMMARY) -f $(FASM_RESULT) -o $@ --verif