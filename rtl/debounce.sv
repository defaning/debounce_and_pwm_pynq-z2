// =============================================================================
// debounce.sv —— 按键消抖 + 单拍脉冲输出(P5 复用,请认真写)
//
// 规格:
//   * 异步按键进来,输出两类信号:
//       level_o : 消抖后的稳定电平
//       pulse_o : 稳定确认后的"单拍"脉冲(每次按下恰 1 拍)
//   * STABLE_CYC: 稳定确认拍数。PYNQ-Z2 20ms@125MHz = 2_500_000(22 位计数器!)
//   * 全同步设计:clk 域,同步低复位 rst_n;输入先打 2 拍(亚稳态缓解)
//
// 参考(可对照学习,不要照抄): ../UIUC_chenlab/OpenRTLSet/020_debouncer
// =============================================================================
`timescale 1ns / 1ps

module debounce #(
    parameter int unsigned STABLE_CYC = 2_500_000,  // 20 ms @ 125 MHz
    parameter int unsigned CNT_W      = 22          // ceil(log2(STABLE_CYC))+1
) (
    input  logic clk,
    input  logic rst_n,
    input  logic btn_i,       // 原始按键(异步,可能有毛刺)
    output logic level_o,     // 消抖后电平
    output logic pulse_o      // 稳定确认后单拍脉冲
);

    // TODO(S1): 你的实现
    // 提示:
    //   1) btn_i 打两拍: btn_ff1/btn_ff2
    //   2) btn_ff2 == level_o ? 计数器清零 : 计数器+1
    //   3) 计数器到 STABLE_CYC-1: level_o <= ~level_o(翻转), 并在 0->1 翻转拍置 pulse_o 一拍
    //   4) pulse_o 必须恰为 1 个 clk 周期 —— S4 的 TB 断言就查这个

    logic [CNT_W-1:0] cnt = '0;
    logic btn_ff1 = 1'b0, btn_ff2 = 1'b0;
    logic level_r = 1'b0;
    logic pulse_r = 1'b0;

    assign level_o = level_r;
    assign pulse_o = pulse_r;

    // TODO(S1): always_ff 逻辑体

endmodule
