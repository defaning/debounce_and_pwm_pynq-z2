// =============================================================================
// pwm_gen.sv —— 通用 PWM 发生器(P2/P5 复用)
//
// 规格:
//   * W 位占空比输入 duty_i;周期 = 2**W 个 clk;高电平拍数 = duty_i
//     (duty=0 → 恒 0;duty=2**W-1 → 周期-1 拍高 —— S4 TB 按此断言)
//   * 输出 pwm_o 必须寄存器化(IO timing 友好,UG906 会查 IOB 寄存)
// =============================================================================
`timescale 1ns / 1ps

module pwm_gen #(
    parameter int unsigned W = 8
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             en_i,      // 0 = 强制输出 0
    input  logic [W-1:0]     duty_i,
    output logic             pwm_o
);

    logic [W-1:0] phase_c = '0;   // 相位计数器 0..2**W-1
    logic         pwm_r  = 1'b0;

    assign pwm_o = pwm_r;

    // TODO(S1):
    //   phase_c 循环 +1;
    //   pwm_r <= en_i && (phase_c < duty_i);
    //   想一想: 比较 phase_c < duty_i 用 phase_c 当前值还是下一拍? 写 TB 前先想清楚。
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_c <= '0;
            pwm_r   <= 1'b0;
        end else begin
            phase_c <= phase_c + 1'b1;
            pwm_r   <= en_i && (phase_c < duty_i);
        end
    end

endmodule
