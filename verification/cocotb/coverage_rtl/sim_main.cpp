#include "Vchip_top_full.h"
#include "verilated.h"
#include "verilated_cov.h"
#include <cstdint>
#include <vector>

static Vchip_top_full* top;

static void tick() {
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();
}

// 48-bit scan frame LSB-first: {tgt[1:0], addr[13:0], data[31:0]}
static void scan_frame(uint8_t tgt, uint16_t addr, uint32_t data) {
    uint64_t frame = ((uint64_t)(tgt & 3) << 46) |
                     ((uint64_t)(addr & 0x3FFF) << 32) |
                     (uint64_t)data;
    for (int i = 0; i < 48; i++) {
        top->scan_in = (frame >> i) & 1;
        top->scan_shift = 1;
        tick();
    }
    top->scan_shift = 0;
    top->scan_in = 0;
    tick();
    top->scan_load = 1;
    tick();
    top->scan_load = 0;
    tick();
}

static void load_words(const std::vector<uint32_t>& prog) {
    for (size_t i = 0; i < prog.size(); i++)
        scan_frame(0, (uint16_t)i, prog[i]);
}

static void start_run() {
    scan_frame(2, 0, 0);          // clkgen cfg
    scan_frame(1, 0, 0x00010000); // FSM RUN
}

static void idle_cycles(int n) {
    for (int i = 0; i < n; i++) tick();
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::assertOn(false);
    top = new Vchip_top_full;

    top->clk = 0;
    top->rst_n = 0;
    top->scan_in = 0;
    top->scan_shift = 0;
    top->scan_load = 0;
    top->scan_i0o1 = 0;
    top->gpio_in = 0;
    top->uart_rx = 1;
    top->clk_int = 0;

    for (int i = 0; i < 20; i++) tick();
    top->rst_n = 1;
    for (int i = 0; i < 10; i++) tick();

    // --- 1) Smoke: GPIO=5, UART='A', SPI=0xB7 (matches directed TB) ---
    {
        std::vector<uint32_t> prog = {
            0x00010537, 0x000205B7, 0x00030637,
            0x0A500293, 0x04100313, 0x0B700393,
            0x00552023, 0x0065A023, 0x00762023,
            0x00000013, 0xFFDFF06F
        };
        load_words(prog);
        start_run();
        idle_cycles(4000);
    }

    // Reset FSM path by soft re-load after holding reset briefly
    top->rst_n = 0;
    idle_cycles(20);
    top->rst_n = 1;
    idle_cycles(10);

    // --- 2) GPIO toggle loop (exercises GPIO + mem + CPU loop) ---
    {
        std::vector<uint32_t> prog = {
            0x00010537, // lui a0, 0x10
            0x00100613, // li  a2, 1
            0x00C52023, // sw  a2, 0(a0)
            0x00000613, // li  a2, 0
            0x00C52023, // sw  a2, 0(a0)
            0xFF1FF06F  // j   loop
        };
        load_words(prog);
        start_run();
        idle_cycles(5000);
    }

    top->rst_n = 0; idle_cycles(20); top->rst_n = 1; idle_cycles(10);

    // --- 3) UART TX one byte 0x55 ---
    {
        std::vector<uint32_t> prog = {
            0x00020537, // lui a0, 0x20
            0x05500293, // li  t0, 0x55
            0x00552223, // sw  t0, 4(a0)
            0x0000006F  // j .
        };
        load_words(prog);
        start_run();
        idle_cycles(3000);
    }

    top->rst_n = 0; idle_cycles(20); top->rst_n = 1; idle_cycles(10);

    // --- 4) SPI TX byte 0xA5 ---
    {
        std::vector<uint32_t> prog = {
            0x00030537, // lui a0, 0x30
            0x0A500293, // li  t0, 0xA5
            0x00552023, // sw  t0, 0(a0)
            0x0000006F  // j .
        };
        load_words(prog);
        start_run();
        idle_cycles(3000);
    }

    top->rst_n = 0; idle_cycles(20); top->rst_n = 1; idle_cycles(10);

    // --- 5) UART RX bit-bang while CPU polls (simple spin) ---
    {
        std::vector<uint32_t> prog = {
            0x00000013, // nop
            0x0000006F  // j .
        };
        load_words(prog);
        start_run();
        // bit-bang 0x3C @ 8 cycles/bit
        auto send_bit = [&](int b) {
            top->uart_rx = b & 1;
            for (int i = 0; i < 8; i++) tick();
        };
        send_bit(0); // start
        for (int i = 0; i < 8; i++) send_bit((0x3C >> i) & 1);
        send_bit(1); // stop
        idle_cycles(2000);
    }

    // --- 6) Many GPIO values (hits more bins + APB writes) ---
    top->rst_n = 0; idle_cycles(20); top->rst_n = 1; idle_cycles(10);
    for (uint32_t v = 1; v <= 31; v++) {
        std::vector<uint32_t> prog = {
            0x00010537,                         // lui a0, 0x10
            0x00000093 | ((v & 0xFFF) << 20), // addi x1, x0, v
            0x00152023,                         // sw  x1, 0(a0)
            0x0000006F                          // j .
        };
        load_words(prog);
        start_run();
        idle_cycles(800);
        top->rst_n = 0; idle_cycles(10); top->rst_n = 1; idle_cycles(5);
    }

    // --- dmem SW/LW (addr 0x10, data 0x15 -> GPIO) ---
    top->rst_n = 0; idle_cycles(20); top->rst_n = 1; idle_cycles(10);
    {
        std::vector<uint32_t> prog = {
            0x01000293, 0x01500313, 0x0062A023, 0x0002A383,
            0x00010537, 0x00752023, 0x0000006F
        };
        load_words(prog);
        start_run();
        idle_cycles(4000);
    }

    // --- denser dmem: SB/LB + multi-addr (exercise narrow gather) ---
    top->rst_n = 0; idle_cycles(20); top->rst_n = 1; idle_cycles(10);
    {
        // a0=0x10 base in dmem region (byte offsets)
        // SB then LB several addresses, XOR fold to GPIO
        std::vector<uint32_t> prog = {
            0x01000513, // addi a0, x0, 0x10
            0x0A100593, // addi a1, x0, 0xA1
            0x00B50023, // sb   a1, 0(a0)
            0x0B200593, // addi a1, x0, 0xB2
            0x00B500A3, // sb   a1, 1(a0)
            0x0C300593, // addi a1, x0, 0xC3
            0x00B50123, // sb   a1, 2(a0)
            0x0D400593, // addi a1, x0, 0xD4
            0x00B501A3, // sb   a1, 3(a0)
            0x00054583, // lbu  a1, 0(a0)
            0x00154603, // lbu  a2, 1(a0)
            0x00C5C5B3, // xor  a1, a1, a2
            0x00254603, // lbu  a2, 2(a0)
            0x00C5C5B3, // xor  a1, a1, a2
            0x00354603, // lbu  a3, 3(a0)
            0x00C5C5B3, // xor  a1, a1, a2  (fold)
            0x00010537, // lui  a0, 0x10   GPIO
            0x00B52023, // sw   a1, 0(a0)
            0x0000006F  // j .
        };
        load_words(prog);
        start_run();
        idle_cycles(8000);
        printf("after denser dmem: gpio_out=%u\n", (unsigned)top->gpio_out);
    }

    // Extra free-run
    idle_cycles(50000);

    top->final();
    VerilatedCov::write("coverage.dat");
    delete top;
    return 0;
}
