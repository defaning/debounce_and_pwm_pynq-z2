// =============================================================================
// edge_detect.sv —�?? 电平→边沿脉冲检测器
//
// 规格:
//   * EDGES: "RISE" / "FALL" / "BOTH"(字符串参�?,综合期展�?为常量比�?)
//   * 输出为单拍脉�?,与输入同�?(输入打一拍后比较)
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
    localparam bit OPT_RISE = (EDGES == "RISE");
    localparam bit OPT_FALL = (EDGES == "FALL");
    localparam bit OPT_BOTH = !(OPT_RISE || OPT_FALL);
    
    logic lvl_d = 1'b0;   // TODO(S1): 打一�?
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lvl_d <= 1'b0;
        end else begin
            lvl_d <= lvl_i;
        end
    end
    
    logic rise, fall;


    // TODO(S1):
    //   rise = lvl_i & ~lvl_d;  fall = ~lvl_i & lvl_d;
    //   edge_o = (EDGES=="RISE") ? rise : (EDGES=="FALL") ? fall : rise|fall;
    //   注意: edge_o 用时序输出还是组合输�?? 建议组合 assign,顶层再用;
    //         �? TB 里要知道它相�? lvl_i 延迟 1 拍�??

    assign rise = lvl_i & ~lvl_d;  // TODO
    assign fall = ~lvl_i & lvl_d;  // TODO
    logic edge_c;
    assign edge_c = (OPT_RISE & rise)
                    | (OPT_FALL & fall)
                    | (OPT_BOTH & (rise | fall));

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_o <= 1'b0;
        end else begin
            edge_o <= edge_c;
        end
    end
endmodule
