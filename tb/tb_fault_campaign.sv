// tb_fault_campaign.sv
// Instruction-class-aware RTL fault injection campaign.
//
// This campaign performs clean single-fault experiments.
// For every injected fault:
//   1. Reset the CPU
//   2. Choose an instruction class window
//   3. Inject one bit-flip fault into one Core B commit-bus field
//   4. Observe comparator detection
//   5. Log result to CSV
//
// No force/release is used.
// Faults are injected only through:
//   fault_en, fault_sel, fault_mask
//
// Core A = golden/reference core
// Core B = checker/faulty core

`timescale 1ns/1ps

module tb_fault_campaign;

    // ------------------------------------------------------------
    // Fault target encoding
    // Must match lockstep_top.sv
    // ------------------------------------------------------------
    localparam logic [2:0] FAULT_NONE     = 3'd0;
    localparam logic [2:0] FAULT_PC       = 3'd1;
    localparam logic [2:0] FAULT_REG_WE   = 3'd2;
    localparam logic [2:0] FAULT_REG_ADDR = 3'd3;
    localparam logic [2:0] FAULT_REG_DATA = 3'd4;
    localparam logic [2:0] FAULT_MEM_WE   = 3'd5;
    localparam logic [2:0] FAULT_MEM_ADDR = 3'd6;
    localparam logic [2:0] FAULT_MEM_DATA = 3'd7;

    // ------------------------------------------------------------
    // Instruction class encoding
    // ------------------------------------------------------------
    localparam int CLASS_IMM    = 0;
    localparam int CLASS_ALU    = 1;
    localparam int CLASS_MEM    = 2;
    localparam int CLASS_BRANCH = 3;
    localparam int CLASS_JUMP   = 4;

    // ------------------------------------------------------------
    // Campaign parameters
    // Total faults = 5 classes * 7 targets * FAULTS_PER_CLASS_TARGET
    // ------------------------------------------------------------
    localparam int NUM_CLASSES = 5;
    localparam int NUM_TARGETS = 7;
    localparam int FAULTS_PER_CLASS_TARGET = 3;
    localparam int OBSERVE_WINDOW = 5;

    // ------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------
    logic        clk;
    logic        reset;

    logic        fault_en;
    logic [2:0]  fault_sel;
    logic [31:0] fault_mask;
    logic        clear_latched;

    logic [31:0] pc0, pc1;
    logic [31:0] reg3_0, reg3_1;
    logic [31:0] mem0_0, mem0_1;

    logic [31:0] a_pc_next,  b_pc_next;
    logic        a_reg_we,   b_reg_we;
    logic [4:0]  a_reg_addr, b_reg_addr;
    logic [31:0] a_reg_data, b_reg_data;
    logic        a_mem_we,   b_mem_we;
    logic [31:0] a_mem_addr, b_mem_addr;
    logic [31:0] a_mem_data, b_mem_data;

    logic        mismatch_now;
    logic        mismatch_latched;
    logic [6:0]  mismatch_field;

    logic        stall_a;
    logic        stall_b;
    logic        stall_any;
    logic        stall_latched;

    // ------------------------------------------------------------
    // Counters
    // ------------------------------------------------------------
    int cycle_count;

    int total_faults;
    int detected_faults;
    int missed_faults;

    int comparator_detected_count;
    int watchdog_seen_count;

    int total_latency;
    int max_latency;

    int injected_per_target [0:7];
    int detected_per_target [0:7];

    int injected_per_class [0:4];
    int detected_per_class [0:4];

    int csv_fd;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    lockstep_top dut (
        .clk              (clk),
        .reset            (reset),

        .fault_en         (fault_en),
        .fault_sel        (fault_sel),
        .fault_mask       (fault_mask),
        .clear_latched    (clear_latched),

        .pc0              (pc0),
        .pc1              (pc1),
        .reg3_0           (reg3_0),
        .reg3_1           (reg3_1),
        .mem0_0           (mem0_0),
        .mem0_1           (mem0_1),

        .a_pc_next        (a_pc_next),
        .a_reg_we         (a_reg_we),
        .a_reg_addr       (a_reg_addr),
        .a_reg_data       (a_reg_data),
        .a_mem_we         (a_mem_we),
        .a_mem_addr       (a_mem_addr),
        .a_mem_data       (a_mem_data),

        .b_pc_next        (b_pc_next),
        .b_reg_we         (b_reg_we),
        .b_reg_addr       (b_reg_addr),
        .b_reg_data       (b_reg_data),
        .b_mem_we         (b_mem_we),
        .b_mem_addr       (b_mem_addr),
        .b_mem_data       (b_mem_data),

        .mismatch_now     (mismatch_now),
        .mismatch_latched (mismatch_latched),
        .mismatch_field   (mismatch_field),

        .stall_a          (stall_a),
        .stall_b          (stall_b),
        .stall_any        (stall_any),
        .stall_latched    (stall_latched)
    );

    // ------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------
    // Cycle counter
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
    end

    // ------------------------------------------------------------
    // Helper: target name
    // ------------------------------------------------------------
    function string target_name(input int sel);
        begin
            case (sel)
                1:       target_name = "PC";
                2:       target_name = "REG_WE";
                3:       target_name = "REG_ADDR";
                4:       target_name = "REG_DATA";
                5:       target_name = "MEM_WE";
                6:       target_name = "MEM_ADDR";
                7:       target_name = "MEM_DATA";
                default: target_name = "NONE";
            endcase
        end
    endfunction

    // ------------------------------------------------------------
    // Helper: instruction class name
    // ------------------------------------------------------------
    function string class_name(input int cls);
        begin
            case (cls)
                CLASS_IMM:    class_name = "IMM";
                CLASS_ALU:    class_name = "ALU";
                CLASS_MEM:    class_name = "MEM";
                CLASS_BRANCH: class_name = "BRANCH";
                CLASS_JUMP:   class_name = "JUMP";
                default:      class_name = "UNKNOWN";
            endcase
        end
    endfunction

    // ------------------------------------------------------------
    // Helper: choose legal bit index per target width
    // ------------------------------------------------------------
    function int choose_bit_index(input int target);
        begin
            case (target)
                2, 5: choose_bit_index = 0;                        // 1-bit fields
                3:    choose_bit_index = $urandom_range(0, 4);     // 5-bit field
                default: choose_bit_index = $urandom_range(0, 31); // 32-bit fields
            endcase
        end
    endfunction

    // ------------------------------------------------------------
    // Helper: choose an injection cycle by instruction class
    //
    // These cycle windows assume the longer IMEM program:
    // IMM    : addi / andi / ori instructions
    // ALU    : add / sub / and / or instructions
    // MEM    : lw / sw instructions
    // BRANCH : beq / bne instructions
    // JUMP   : j instruction
    //
    // We inject before the final infinite loop.
    // ------------------------------------------------------------
    function int choose_inject_cycle(input int cls);
        int r;
        begin
            case (cls)

                CLASS_IMM: begin
                    r = $urandom_range(0, 7);
                    case (r)
                        0: choose_inject_cycle = 1;
                        1: choose_inject_cycle = 2;
                        2: choose_inject_cycle = 7;
                        3: choose_inject_cycle = 8;
                        4: choose_inject_cycle = 9;
                        5: choose_inject_cycle = 17;
                        6: choose_inject_cycle = 20;
                        default: choose_inject_cycle = 23;
                    endcase
                end

                CLASS_ALU: begin
                    r = $urandom_range(0, 5);
                    case (r)
                        0: choose_inject_cycle = 3;
                        1: choose_inject_cycle = 4;
                        2: choose_inject_cycle = 5;
                        3: choose_inject_cycle = 6;
                        4: choose_inject_cycle = 15;
                        default: choose_inject_cycle = 26;
                    endcase
                end

                CLASS_MEM: begin
                    r = $urandom_range(0, 6);
                    case (r)
                        0: choose_inject_cycle = 10;
                        1: choose_inject_cycle = 11;
                        2: choose_inject_cycle = 12;
                        3: choose_inject_cycle = 13;
                        4: choose_inject_cycle = 14;
                        5: choose_inject_cycle = 24;
                        default: choose_inject_cycle = 25;
                    endcase
                end

                CLASS_BRANCH: begin
                    r = $urandom_range(0, 1);
                    if (r == 0)
                        choose_inject_cycle = 16;
                    else
                        choose_inject_cycle = 18;
                end

                CLASS_JUMP: begin
                    choose_inject_cycle = 21;
                end

                default: begin
                    choose_inject_cycle = 5;
                end

            endcase
        end
    endfunction

    // ------------------------------------------------------------
    // Reset helper
    // ------------------------------------------------------------
    task automatic apply_reset;
        begin
            reset         = 1'b1;
            fault_en      = 1'b0;
            fault_sel     = FAULT_NONE;
            fault_mask    = 32'h0000_0000;
            clear_latched = 1'b0;

            repeat (4) @(posedge clk);

            @(negedge clk);
            reset = 1'b0;
        end
    endtask

    // ------------------------------------------------------------
    // Clear sticky flags
    // ------------------------------------------------------------
    task automatic clear_detection_flags;
        begin
            clear_latched = 1'b1;
            @(posedge clk);
            #1;
            clear_latched = 1'b0;
        end
    endtask

    // ------------------------------------------------------------
    // Run one clean single-fault experiment
    // ------------------------------------------------------------
    task automatic run_one_fault(
        input int fault_id,
        input int instr_class,
        input int this_target
    );
        int          bit_index;
        int          hold_cycles;
        int          requested_inject_cycle;
        int          actual_inject_cycle;
        int          detect_cycle;
        int          latency;

        bit          detected;
        bit          comparator_detected;
        bit          watchdog_seen;
        logic [6:0]  detected_field;

        begin
            detected            = 0;
            comparator_detected = 0;
            watchdog_seen       = 0;
            detected_field      = 7'b0000000;
            detect_cycle        = -1;
            latency             = -1;

            // Each fault starts from a clean CPU state
            apply_reset();

            requested_inject_cycle = choose_inject_cycle(instr_class);
            bit_index              = choose_bit_index(this_target);
            hold_cycles            = $urandom_range(1, 5);

            fault_sel  = this_target[2:0];
            fault_mask = (32'h0000_0001 << bit_index);

            // Wait until just before the chosen injection cycle
            if (requested_inject_cycle > 1) begin
                repeat (requested_inject_cycle - 1) @(posedge clk);
            end

            @(negedge clk);
            actual_inject_cycle = cycle_count + 1;
            fault_en = 1'b1;

            $display("FAULT %0d START | class=%s | target=%s | bit=%0d | mask=%08h | cycle=%0d | duration=%0d",
                     fault_id,
                     class_name(instr_class),
                     target_name(this_target),
                     bit_index,
                     fault_mask,
                     actual_inject_cycle,
                     hold_cycles);

            // Fault active window
            repeat (hold_cycles) begin
                @(posedge clk);
                #1;

                if (stall_any || stall_latched)
                    watchdog_seen = 1;

                if (!detected && (mismatch_now || mismatch_latched)) begin
                    detected            = 1;
                    comparator_detected = 1;
                    detect_cycle        = cycle_count;
                    detected_field      = mismatch_field;
                end
            end

            // Remove fault
            @(negedge clk);
            fault_en   = 1'b0;
            fault_sel  = FAULT_NONE;
            fault_mask = 32'h0000_0000;

            // Observation window
            repeat (OBSERVE_WINDOW) begin
                @(posedge clk);
                #1;

                if (stall_any || stall_latched)
                    watchdog_seen = 1;

                if (!detected && (mismatch_now || mismatch_latched)) begin
                    detected            = 1;
                    comparator_detected = 1;
                    detect_cycle        = cycle_count;
                    detected_field      = mismatch_field;
                end
            end

            // Update statistics
            total_faults++;
            injected_per_target[this_target]++;
            injected_per_class[instr_class]++;

            if (detected) begin
                detected_faults++;
                detected_per_target[this_target]++;
                detected_per_class[instr_class]++;

                latency = detect_cycle - actual_inject_cycle;
                total_latency += latency;

                if (latency > max_latency)
                    max_latency = latency;

                if (comparator_detected)
                    comparator_detected_count++;

                if (watchdog_seen)
                    watchdog_seen_count++;

                $display("FAULT %0d RESULT | DETECTED | latency=%0d | cmp=%0b | watchdog_seen=%0b | field=%07b",
                         fault_id,
                         latency,
                         comparator_detected,
                         watchdog_seen,
                         detected_field);
            end else begin
                missed_faults++;

                if (watchdog_seen)
                    watchdog_seen_count++;

                $display("FAULT %0d RESULT | MISSED | watchdog_seen=%0b",
                         fault_id,
                         watchdog_seen);
            end

            // CSV line
            $fdisplay(csv_fd,
                      "%0d,%0s,%0s,%0d,%08h,%0d,%0d,%0d,%0d,%0d,%0d,%07b",
                      fault_id,
                      class_name(instr_class),
                      target_name(this_target),
                      bit_index,
                      fault_mask,
                      actual_inject_cycle,
                      hold_cycles,
                      detected,
                      latency,
                      comparator_detected,
                      watchdog_seen,
                      detected_field);

            clear_detection_flags();
        end
    endtask

    // ------------------------------------------------------------
    // Main
    // ------------------------------------------------------------
    initial begin
        int fault_id;

        $dumpfile("fault_campaign.vcd");
        $dumpvars(0, tb_fault_campaign);

        total_faults              = 0;
        detected_faults           = 0;
        missed_faults             = 0;
        comparator_detected_count = 0;
        watchdog_seen_count       = 0;
        total_latency             = 0;
        max_latency               = 0;

        for (int t = 0; t < 8; t++) begin
            injected_per_target[t] = 0;
            detected_per_target[t] = 0;
        end

        for (int c = 0; c < 5; c++) begin
            injected_per_class[c] = 0;
            detected_per_class[c] = 0;
        end

        csv_fd = $fopen("fault_results.csv", "w");
        if (csv_fd == 0) begin
            $display("ERROR: could not open fault_results.csv");
            $finish;
        end

        $fdisplay(csv_fd,
                  "fault_id,instruction_class,target,bit_index,fault_mask,inject_cycle,duration,detected,latency,comparator_detected,watchdog_seen,mismatch_field");

        $display("");
        $display("============================================================");
        $display(" Starting Instruction-Class-Aware RTL Fault Campaign");
        $display("============================================================");

        fault_id = 0;

        for (int c = 0; c < NUM_CLASSES; c++) begin
            for (int t = 1; t <= NUM_TARGETS; t++) begin
                for (int n = 0; n < FAULTS_PER_CLASS_TARGET; n++) begin
                    run_one_fault(fault_id, c, t);
                    fault_id++;
                end
            end
        end

        $display("");
        $display("============================================================");
        $display(" Fault Campaign Summary");
        $display("============================================================");
        $display("Total faults              = %0d", total_faults);
        $display("Detected faults           = %0d", detected_faults);
        $display("Missed faults             = %0d", missed_faults);

        if (total_faults > 0) begin
            $display("Coverage                  = %0d / %0d = %0.2f%%",
                     detected_faults,
                     total_faults,
                     (detected_faults * 100.0) / total_faults);
        end

        $display("Comparator detections     = %0d", comparator_detected_count);
        $display("Watchdog seen events      = %0d", watchdog_seen_count);

        if (detected_faults > 0) begin
            $display("Average latency           = %0.2f cycles",
                     (total_latency * 1.0) / detected_faults);
            $display("Max latency               = %0d cycles", max_latency);
        end

        $display("");
        $display("Coverage per target:");
        for (int t = 1; t <= NUM_TARGETS; t++) begin
            if (injected_per_target[t] > 0) begin
                $display("  %-8s : %0d / %0d = %0.2f%%",
                         target_name(t),
                         detected_per_target[t],
                         injected_per_target[t],
                         (detected_per_target[t] * 100.0) / injected_per_target[t]);
            end
        end

        $display("");
        $display("Coverage per instruction class:");
        for (int c = 0; c < NUM_CLASSES; c++) begin
            if (injected_per_class[c] > 0) begin
                $display("  %-8s : %0d / %0d = %0.2f%%",
                         class_name(c),
                         detected_per_class[c],
                         injected_per_class[c],
                         (detected_per_class[c] * 100.0) / injected_per_class[c]);
            end
        end

        $display("============================================================");
        $display("CSV written to fault_results.csv");
        $display("============================================================");
        $display("");

        $fclose(csv_fd);
        $finish;
    end

endmodule