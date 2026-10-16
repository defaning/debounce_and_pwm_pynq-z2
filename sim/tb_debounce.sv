// =============================================================================
// tb_debounce.sv —— 消抖器自校验 TB(骨架)
//
// 核心断言(README S4):对每组激励——
//   A. 毛刺期(每段 < STABLE_CYC 的翻转)绝不产生 pulse;
//   B. 稳定 STABLE_CYC 后,pulse 恰好 1 拍,且仅 1 拍;
//   C. level_o 在 pulse 后等于按键稳定电平。
// 抖动构造:按下前给 3~5 段随机宽度(100~500_000 拍)毛刺,再稳定按下 > STABLE_CYC。
// =============================================================================
`timescale 1ns / 1ps

module tb_debounce;

    localparam int CLK_NS   = 8;
    localparam int STABLE   = 2_500_000;           // 与 DUT 一致
    localparam int TIMEOUT  = 100_000_000;         // 看门狗(拍)

    logic clk = 0, rst_n = 0, btn = 0;
    logic level, pulse;

    int errors = 0, checks = 0, pulse_cnt = 0;

    always #(CLK_NS/2.0) clk = ~clk;

    initial begin repeat (TIMEOUT) @(posedge clk);
        $fatal(1, "TB-RESULT: FAIL (timeout)"); end

    debounce #(.STABLE_CYC(STABLE), .CNT_W(22)) u_dut (
        .clk(clk), .rst_n(rst_n), .btn_i(btn), .level_o(level), .pulse_o(pulse));

    // 统计整个仿真中 pulse 总拍数(断言 B 用)
    always @(posedge clk) if (pulse) pulse_cnt++;

    // TODO(S4): 任务 task glitch(input int len);  // 拉高/拉低随机宽度毛刺
    // TODO(S4): 激励序列 ×5 组(不同毛刺形态),每组后:
    //   检查1: pulse_cnt 恰好 +1(毛刺期间没有提前触发);
    //   检查2: pulse 高电平只持续 1 拍(用连续两拍采样判断);
    //   检查3: level == 1。
    //   全部通过 checks++,失败 errors++ 并打印时间戳。

    initial begin
        repeat (5) @(posedge clk); rst_n = 1;
        // TODO(S4): 你的 5 组激励 + 检查
        #1;
        if (errors == 0) begin $display("TB-RESULT: PASS (%0d checks)", checks); $finish; end
        else begin $display("TB-RESULT: FAIL (%0d errors)", errors); $fatal(1); end
    end

endmodule
