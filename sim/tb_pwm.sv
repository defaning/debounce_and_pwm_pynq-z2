// =============================================================================
// tb_pwm.sv —— PWM 自校验 TB(骨架)
//
// 核心断言(README S4):对 duty ∈ {0, 128, 255}(自行加随机档):
//   * 连续 2 个 PWM 周期(2*256 拍)统计高电平拍数 high_cnt;
//   * 期望:duty=0 → 0;duty=128 → 256;duty=255 → 510;
//   * en=0 时输出恒 0。
// =============================================================================
`timescale 1ns / 1ps

module tb_pwm;

    localparam int CLK_NS = 8, TIMEOUT = 1_000_000;

    logic clk = 0, rst_n = 0, en = 1, pwm;
    logic [7:0] duty = 0;

    int errors = 0, checks = 0;

    always #(CLK_NS/2.0) clk = ~clk;
    initial begin repeat (TIMEOUT) @(posedge clk);
        $fatal(1, "TB-RESULT: FAIL (timeout)"); end

    pwm_gen #(.W(8)) u_dut (.clk(clk), .rst_n(rst_n), .en_i(en), .duty_i(duty), .pwm_o(pwm));

    // TODO(S4): task measure(input [7:0] d, input int exp_high);
    //   duty=d; 等待相位对齐;连续 512 拍统计 pwm 为高的拍数;与 exp_high 比对。

    initial begin
        repeat (5) @(posedge clk); rst_n = 1;
        // TODO(S4): measure(0,0); measure(128,256); measure(255,510);
        //           随机 20 档:measure($urandom_range(0,255), duty);
        //            en=0: 断言连续 100 拍 pwm==0
        if (errors == 0) begin $display("TB-RESULT: PASS (%0d checks)", checks); $finish; end
        else begin $display("TB-RESULT: FAIL (%0d errors)", errors); $fatal(1); end
    end

endmodule
