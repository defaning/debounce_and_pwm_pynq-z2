// =============================================================================
// edge_detect.sv —— 电平→边沿脉冲检测器
//
// 规格:
//   * EDGES: "RISE" / "FALL" / "BOTH"(字符串参数,综合期展开为常量比较)
//   * 输出为单拍脉冲,与输入同拍(输入打一拍后比较)
// =============================================================================
`timescale 1ns / 1ps

module edge_detect #(
    parameter string EDGES = "RISE"
) (
    input  logic clk,
    input  logic rst_n,
    input  logic lvl_i,
    output logic edge_o
);

    logic lvl_d = 1'b0;   // TODO(S1): 打一拍
    logic rise, fall;

    // TODO(S1):
    //   rise = lvl_i & ~lvl_d;  fall = ~lvl_i & lvl_d;
    //   edge_o = (EDGES=="RISE") ? rise : (EDGES=="FALL") ? fall : rise|fall;
    //   注意: edge_o 用时序输出还是组合输出? 建议组合 assign,顶层再用;
    //         但 TB 里要知道它相对 lvl_i 延迟 1 拍。

    assign rise = 1'b0;  // TODO
    assign fall = 1'b0;  // TODO
    assign edge_o = 1'b0;  // TODO

endmodule
