
module tb_mac32_signed;

    reg               clk;
    reg               rst_n;

    reg               mac_en;
    reg               mac_init;

    reg signed [31:0] a;
    reg signed [31:0] b;

    wire signed [63:0] acc;

    // ============================================================
    // Reference model
    // ============================================================

    reg signed [63:0] expected_acc;

    integer pass_count;
    integer fail_count;

    //reg signed [63:0] expected_product;

    // ============================================================
    // DUT
    // ============================================================

    mac32_signed dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .mac_en   (mac_en),
        .mac_init (mac_init),
        .a        (a),
        .b        (b),
        .acc      (acc)
    );


    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task check_result;

        input signed [63:0] expected;
        input [255:0] test_name;

        begin

            if (acc === expected) begin

                $display(
                    "[PASS] %s : Expected = %0d, DUT = %0d",
                    test_name,
                    expected,
                    acc
                );

                pass_count = pass_count + 1;

            end
            else begin

                $display(
                    "[FAIL] %s : Expected = %0d, DUT = %0d",
                    test_name,
                    expected,
                    acc
                );

                fail_count = fail_count + 1;

            end

        end

    endtask

    // ============================================================
    // MAC INIT
    //
    // ACC = A * B
    // ============================================================

    task mac_init_operation;

        input signed [31:0] x;
        input signed [31:0] y;
        input [255:0] test_name;

        reg signed [63:0] product_ref;

        begin

            product_ref = $signed(x) * $signed(y);

            // Apply inputs before rising edge
            @(negedge clk);

            a        = x;
            b        = y;
            mac_init = 1'b1;
            mac_en   = 1'b1;

            // MAC operation occurs here
            @(posedge clk);
            #1;

            expected_acc = product_ref;

            check_result(
                expected_acc,
                test_name
            );

            // Disable MAC
            @(negedge clk);

            mac_en   = 1'b0;
            mac_init = 1'b0;

        end

    endtask

    // ============================================================
    // MAC ACCUMULATE
    //
    // ACC = ACC + A * B
    // ============================================================

    task mac_operation;

        input signed [31:0] x;
        input signed [31:0] y;
        input [255:0] test_name;

        reg signed [63:0] product_ref;

        begin

            product_ref = $signed(x) * $signed(y);

            // Apply inputs before rising edge
            @(negedge clk);

            a        = x;
            b        = y;
            mac_init = 1'b0;
            mac_en   = 1'b1;

            // MAC operation
            @(posedge clk);
            #1;

            expected_acc = expected_acc + product_ref;

            check_result(
                expected_acc,
                test_name
            );

            // Disable MAC
            @(negedge clk);

            mac_en = 1'b0;

        end

    endtask

    // ============================================================
    // Reset test
    // ============================================================

    task reset_test;

        begin

            rst_n    = 1'b0;
            mac_en   = 1'b0;
            mac_init = 1'b0;

            a = 32'sd0;
            b = 32'sd0;

            expected_acc = 64'sd0;

            repeat (2)
                @(posedge clk);

            #1;

            if (acc === 64'sd0) begin

                $display("[PASS] RESET : ACC = 0");

                pass_count = pass_count + 1;

            end
            else begin

                $display(
                    "[FAIL] RESET : ACC = %0d, Expected = 0",
                    acc
                );

                fail_count = fail_count + 1;

            end

            rst_n = 1'b1;

            @(posedge clk);
            #1;

        end

    endtask

    // ============================================================
    // Main test sequence
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // Initial values
        // --------------------------------------------------------

        clk      = 1'b0;
        rst_n    = 1'b0;

        mac_en   = 1'b0;
        mac_init = 1'b0;

        a = 32'sd0;
        b = 32'sd0;

        expected_acc = 64'sd0;

        pass_count = 0;
        fail_count = 0;

        // --------------------------------------------------------
        // RESET
        // --------------------------------------------------------

        reset_test;

        // ========================================================
        // BASIC MULTIPLICATION TESTS
        // ========================================================

        mac_init_operation(
            32'sd10,
            32'sd20,
            "10 x 20"
        );

        // Expected = 200


        mac_init_operation(
            32'sd5,
            32'sd6,
            "5 x 6"
        );

        // Expected = 30


        // ========================================================
        // SIGNED MULTIPLICATION TESTS
        // ========================================================

        mac_init_operation(
            -32'sd3,
            32'sd4,
            "-3 x 4"
        );

        // Expected = -12


        mac_init_operation(
            32'sd3,
            -32'sd4,
            "3 x -4"
        );

        // Expected = -12


        mac_init_operation(
            -32'sd3,
            -32'sd4,
            "-3 x -4"
        );

        // Expected = +12


        // ========================================================
        // ZERO TEST
        // ========================================================

        mac_init_operation(
            32'sd0,
            32'sd12345,
            "0 x 12345"
        );

        // Expected = 0


        // ========================================================
        // ACCUMULATION TEST
        // ========================================================

        mac_init_operation(
            32'sd10,
            32'sd20,
            "INIT: 10 x 20"
        );

        // ACC = 200


        mac_operation(
            32'sd5,
            32'sd6,
            "ACC: 200 + 5 x 6"
        );

        // ACC = 230


        mac_operation(
            -32'sd3,
            32'sd4,
            "ACC: 230 + (-3 x 4)"
        );

        // ACC = 218


        mac_operation(
            -32'sd10,
            -32'sd2,
            "ACC: 218 + (-10 x -2)"
        );

        // ACC = 238


        // ========================================================
        // INT32 MAXIMUM TEST
        // ========================================================

        mac_init_operation(
            32'h7fffffff,
            32'sd1,
            "INT32_MAX x 1"
        );

        // Expected = 2147483647


        // ========================================================
        // INT32 MINIMUM TEST
        // ========================================================

        mac_init_operation(
            32'h80000000,
            32'sd1,
            "INT32_MIN x 1"
        );

        // Expected = -2147483648


        // ========================================================
        // INT32_MIN x -1
        // ========================================================

        mac_init_operation(
            32'h80000000,
            -32'sd1,
            "INT32_MIN x -1"
        );

        // Expected = +2147483648


        // ========================================================
        // INT32_MIN x INT32_MIN
        // ========================================================

        mac_init_operation(
            32'h80000000,
            32'h80000000,
            "INT32_MIN x INT32_MIN"
        );

        // Expected = 2^62
        // 4611686018427387904


        // ========================================================
        // INT32_MAX x INT32_MAX
        // ========================================================

        mac_init_operation(
            32'h7fffffff,
            32'h7fffffff,
            "INT32_MAX x INT32_MAX"
        );


        // ========================================================
        // -1 x -1
        // ========================================================

        mac_init_operation(
            -32'sd1,
            -32'sd1,
            "-1 x -1"
        );


        // ========================================================
        // -1 x MAX
        // ========================================================

        mac_init_operation(
            -32'sd1,
            32'h7fffffff,
            "-1 x INT32_MAX"
        );


        // ========================================================
        // ACCUMULATOR HOLD TEST
        // ========================================================

        mac_init_operation(
            32'sd100,
            32'sd5,
            "HOLD TEST INIT"
        );

        // ACC = 500

        @(posedge clk);
        #1;

        check_result(
            64'sd500,
            "ACC HOLD"
        );


        // ========================================================
        // LONG ACCUMULATION TEST
        // ========================================================

        mac_init_operation(
            32'sd1,
            32'sd1,
            "LONG ACC INIT"
        );

        // ACC = 1

        repeat (100) begin

            mac_operation(
                32'sd100,
                32'sd100,
                "LONG ACC 100x100"
            );

        end

        // Final expected:
        //
        // 1 + 100*(100*100)
        //
        // = 1000001


        // ========================================================
        // FINAL SUMMARY
        // ========================================================

        $display("");
        $display("================================================");
        $display("           MAC32 SIGNED TEST SUMMARY");
        $display("================================================");
        $display("PASS COUNT = %0d", pass_count);
        $display("FAIL COUNT = %0d", fail_count);
        $display("================================================");

        if (fail_count == 0) begin

            $display("RESULT : ALL TESTS PASSED");

        end
        else begin

            $display("RESULT : TEST FAILED");

        end

        $display("================================================");

        $finish;

    end

endmodule
