.PHONY: all uart gpio spi mem fsm scan scan_fsm ahb block-regress

all: uart gpio spi mem fsm scan scan_fsm ahb
	@echo "=== ALL BLOCK MDV PASS ==="

uart:
	$(MAKE) -C uart block-regress

gpio:
	$(MAKE) -C gpio block-regress

spi:
	$(MAKE) -C spi block-regress

mem:
	$(MAKE) -C mem block-regress
	$(MAKE) -C mem clean
	$(MAKE) -C mem imem-load

fsm:
	$(MAKE) -C fsm block-regress

scan:
	$(MAKE) -C scan block-regress

scan_fsm:
	$(MAKE) -C scan_fsm block-regress

ahb:
	$(MAKE) -C ahb block-regress

block-regress: all
