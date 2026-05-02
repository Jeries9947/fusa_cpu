// tb_internal_fault_campaign.sv
//
// Campaign 2: Internal checker-core fault injection campaign.
//
// This campaign injects faults inside Core B before the commit bus.
// It is separate from Campaign 1.
//
// Core A = clean golden reference
// Core B = faultable checker core
//
// Internal fault targets:
//   1  = ALU_RESULT
//   2  = RS_DATA
//   3  = RT_DATA
//   4  = REG_WRITE
//   5  = MEM_WRITE
//   6  = PC_NEXT
//   7  = WB_DATA
//   8  = PC_HOLD
//   9  = ALU_SRC_IMM
//   10 = REG_DST
//   11 = MEM_TO_REG
//   12 = BRANCH_EQ
//   13 = BRANCH_NE
//   14 = JUMP
//   15 = ALU_CTRL

`timescale 1ns/1ps

module tb_internal_fault_campaign;

    // ------------------------------------------------------------
    // Internal fault target encoding
    // Must match cpu_single_cycle_faultable.sv
    // ------------------------------------------------------------
    localparam logic [3:0] INT_FAULT_NONE        = 4'd0;
    localparam logic [3:0] INT_FAULT_ALU_RESULT  = 4'd1;
    localparam logic [3:0] INT_FAULT_RS_DATA     = 4'd2;
    localparam logic [3:0] INT_FAULT_RT_DATA     = 4'd3;
    localparam logic [3:0] INT_FAULT_REG_WRITE   = 4'd4;
    localparam logic [3:0] INT_FAULT_MEM_WRITE   = 4'd5;
    localparam logic [3:0] INT_FAULT_PC_NEXT     = 4'd6;
    localparam logic [3:0] INT_FAULT_WB_DATA     = 4'd7;
    localparam logic [3:0] INT_FAULT_PC_HOLD     = 4'd8;
    localparam logic [3:0] INT_FAULT_ALU_SRC_IMM = 4'd9;
    localparam logic [3:0] INT_FAULT_REG_DST     = 4'd10;
    localparam logic [3:0] INT_FAULT_MEM_TO_REG  = 4'd11;
    localparam logic [3:0] INT_FAULT_BRANCH_EQ   = 4'd12;
    localparam logic [3:0] INT_FAULT_BRANCH_NE   = 4'd13;
    localparam logic [3:0] INT_FAULT_JUMP        = 4'd14;
    localparam logic [3:0] INT_FAULT_ALU_CTRL    = 4'd15;

    // ------------------------------------------------------------
    // Instruction class encoding
    // ------------------------------------------------------------
    localparam int CLASS_IMM    = 0;
    localparam int CLASS_ALU    = 1;
    localparam int CLASS_MEM    = 2;
    localparam int CLASS_BRANCH = 3;
    localparam int CLASS_JUMP   = 4;

    localparam int NUM_CLASSES = 5;
    localparam int NUM_TARGETS = 15;

    // Total faults = 5 classes * 15 targets * 3 = 225
    localparam int FAULTS_PER_CLASS_TARGET = 3;
    localparam int OBSERVE_WINDOW = 5;

    // ------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------
    logic        clk;
    logic        reset;

    logic        int_fault_en;
    logic [3:0]  int_fault_sel;
    logic [31:0] int_fault_mask;
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
    int not_observed_faults;

    int comparator_detected_count;
    int watchdog_seen_count;

    int total_latency;
    int max_latency;

    int injected_per_target [0:15];
    int detected_per_target [0:15];

    int injected_per_class [0:4];
    int detected_per_class [0:4];

    int csv_fd;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    lockstep_top_internal_fault dut (
        .clk              (clk),
        .reset            (reset),

        .int_fault_en     (int_fault_en),
        .int_fault_sel    (int_fault_sel),
        .int_fault_mask   (int_fault_mask),
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
    // Names
    // ------------------------------------------------------------
    function string target_name(input int sel);
        begin
            case (sel)
                1:       target_name = "ALU_RESULT";
                2:       target_name = "RS_DATA";
                3:       target_name = "RT_DATA";
                4:       target_name = "REG_WRITE";
                5:       target_name = "MEM_WRITE";
                6:       target_name = "PC_NEXT";
                7:       target_name = "WB_DATA";
                8:       target_name = "PC_HOLD";
                9:       target_name = "ALU_SRC_IMM";
                10:      target_name = "REG_DST";
                11:      target_name = "MEM_TO_REG";
                12:      target_name = "BRANCH_EQ";
                13:      target_name = "BRANCH_NE";
                14:      target_name = "JUMP";
                15:      target_name = "ALU_CTRL";
                default: target_name = "NONE";
            endcase
        end
    endfunction

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
    // Legal bit per target
    // ------------------------------------------------------------
    function int choose_bit_index(input int target);
        begin
            case (target)
                // 1-bit control signals
                4, 5, 8, 9, 10, 11, 12, 13, 14:
                    choose_bit_index = 0;

                // ALU_CTRL is 4 bits
                15:
                    choose_bit_index = $urandom_range(0, 3);

                // 32-bit datapath signals
                default:
                    choose_bit_index = $urandom_range(0, 31);
            endcase
        end
    endfunction

    // ------------------------------------------------------------
    // Choose injection cycle by instruction class
    // Same window mapping as Campaign 1.
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
            reset          = 1'b1;
            int_fault_en   = 1'b0;
            int_fault_sel  = INT_FAULT_NONE;
            int_fault_mask = 32'h0000_0000;
            clear_latched  = 1'b0;

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
    // Run one internal fault experiment
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

            // Clean state for each fault
            apply_reset();

            requested_inject_cycle = choose_inject_cycle(instr_class);
            bit_index              = choose_bit_index(this_target);
            hold_cycles            = $urandom_range(1, 5);

            int_fault_sel  = this_target[3:0];
            int_fault_mask = (32'h0000_0001 << bit_index);

            // Wait before chosen instruction/cycle
            if (requested_inject_cycle > 1) begin
                repeat (requested_inject_cycle - 1) @(posedge clk);
            end

            @(negedge clk);
            actual_inject_cycle = cycle_count + 1;
            int_fault_en = 1'b1;

            $display("FAULT %0d START | class=%s | target=%s | bit=%0d | mask=%08h | cycle=%0d | duration=%0d",
                     fault_id,
                     class_name(instr_class),
                     target_name(this_target),
                     bit_index,
                     int_fault_mask,
                     actual_inject_cycle,
                     hold_cycles);

            // Fault active window
            repeat (hold_cycles) begin
                @(posedge clk);
                #1;

                if (stall_any || stall_latched)
                    watchdog_seen = 1;

                if (!detected && mismatch_now) begin
                    detected            = 1;
                    comparator_detected = 1;
                    detect_cycle        = cycle_count;
                    detected_field      = mismatch_field;
                end else if (!detected && mismatch_latched) begin
                    detected            = 1;
                    comparator_detected = 1;
                    detect_cycle        = cycle_count;
                    detected_field      = 7'b0000000;
                end
            end

            // Remove fault
            @(negedge clk);
            int_fault_en   = 1'b0;
            int_fault_sel  = INT_FAULT_NONE;
            int_fault_mask = 32'h0000_0000;

            // Observation window
            repeat (OBSERVE_WINDOW) begin
                @(posedge clk);
                #1;

                if (stall_any || stall_latched)
                    watchdog_seen = 1;

                if (!detected && mismatch_now) begin
                    detected            = 1;
                    comparator_detected = 1;
                    detect_cycle        = cycle_count;
                    detected_field      = mismatch_field;
                end else if (!detected && mismatch_latched) begin
                    detected            = 1;
                    comparator_detected = 1;
                    detect_cycle        = cycle_count;
                    detected_field      = 7'b0000000;
                end
            end

            // Stats
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
                not_observed_faults++;

                if (watchdog_seen)
                    watchdog_seen_count++;

                $display("FAULT %0d RESULT | NOT_OBSERVED | watchdog_seen=%0b",
                         fault_id,
                         watchdog_seen);
            end

            // CSV
            $fdisplay(csv_fd,
                      "%0d,%0s,%0s,%0d,%08h,%0d,%0d,%0d,%0d,%0d,%0d,%07b",
                      fault_id,
                      class_name(instr_class),
                      target_name(this_target),
                      bit_index,
                      int_fault_mask,
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

        $dumpfile("internal_fault_campaign.vcd");
        $dumpvars(0, tb_internal_fault_campaign);

        total_faults              = 0;
        detected_faults           = 0;
        not_observed_faults       = 0;
        comparator_detected_count = 0;
        watchdog_seen_count       = 0;
        total_latency             = 0;
        max_latency               = 0;

        for (int t = 0; t < 16; t++) begin
            injected_per_target[t] = 0;
            detected_per_target[t] = 0;
        end

        for (int c = 0; c < 5; c++) begin
            injected_per_class[c] = 0;
            detected_per_class[c] = 0;
        end

        csv_fd = $fopen("internal_fault_results.csv", "w");
        if (csv_fd == 0) begin
            $display("ERROR: could not open internal_fault_results.csv");
            $finish;
        end

        $fdisplay(csv_fd,
                  "fault_id,instruction_class,target,bit_index,fault_mask,inject_cycle,duration,observed,latency,comparator_detected,watchdog_seen,mismatch_field");

        $display("");
        $display("============================================================");
        $display(" Starting Internal Checker-Core Fault Campaign");
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
        $display(" Internal Fault Campaign Summary");
        $display("============================================================");
        $display("Total faults              = %0d", total_faults);
        $display("Detected faults           = %0d", detected_faults);
        $display("Not observed faults       = %0d", not_observed_faults);

        if (total_faults > 0) begin
            $display("Raw observed coverage     = %0d / %0d = %0.2f%%",
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
        $display("Coverage per internal target:");
        for (int t = 1; t <= NUM_TARGETS; t++) begin
            if (injected_per_target[t] > 0) begin
                $display("  %-12s : %0d / %0d = %0.2f%%",
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
        $display("CSV written to internal_fault_results.csv");
        $display("============================================================");
        $display("");

        $fclose(csv_fd);
        $finish;
    end

endmodule