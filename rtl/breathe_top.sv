// =============================================================================
// breathe_top.sv —�?? P1 顶层:消抖×4 + 模式FSM + 呼吸�? + PWM + VIO/ILA 探针
//
// 模式定义(README §1):
//   0=常亮  1=呼吸(三角�?)  2=闪烁(方波)  3=手动PWM(VIO �? vio_duty)
// 按键: BTN0 换模�? | BTN1 速度± | BTN2 手动duty+16 | BTN3 使能
// LED : led0=PWM输出  led1=模式(亮度4档编�?)  led2=1Hz心跳  led3=使能
// =============================================================================
`timescale 1ns / 1ps

module breathe_top (
    input  logic       sys_clk,     // 125 MHz (H16)
    input  logic [3:0] btn,         // D19/D20/L20/L19
    input  logic [1:0] sw,          // M20/M19(本版未用,留给进阶)
    output logic [3:0] led          // R14/P14/N16/M14 (默认高有�?,若XDC低有效请自行取反)
);

    // ==================================================================
    // 0) 上电复位:计数 2^20 �?(�?8.4ms)后释�?
    // ==================================================================
    logic rst_n;
    logic [19:0] por_cnt = '0;
    always_ff @(posedge sys_clk) begin
        if (por_cnt == 20'hFFFFF) por_cnt <= por_cnt;
        else                      por_cnt <= por_cnt + 1'b1;
    end
    assign rst_n = (por_cnt == 20'hFFFFF);

    // ==================================================================
    // 1) VIO 连线(提前声明,后续多处引用)
    //    S4 仿真/前期综合:�? initial 给安全默认�??(无其他驱动→综合成常�?)
    //    S5 �? vio_0 �?:删除 initial,改由 VIO IP 驱动
    // ==================================================================
    logic       vio_mode_ovr_en;   // VIO out:1=VIO 接管,强制模式3(手动PWM)
    logic [7:0] vio_duty;          // VIO out:模式3 基准占空�?(已修正为8bit!)
    logic       vio_en;            // VIO out:全局使能(�? BTN3 相与)
    logic [2:0] vio_speed;         // VIO out:!=0 时覆盖按键�?�度�?
    logic [1:0] vio_mode;          // VIO in :回读当前生效模式
    logic [7:0] vio_duty_now;      // VIO in :回读当前生效占空�?

/*    initial begin
        vio_mode_ovr_en = 1'b0;
        vio_duty        = 8'h80;
        vio_en          = 1'b1;
        vio_speed       = 3'd2;
    end*/

    // ==================================================================
    // 2) 消抖 ×4(两拍同步 + 稳定 2.5M 拍≈20ms + 上升沿单脉冲)
    // ==================================================================
    logic [3:0] btn_level, btn_pulse;
    debounce #(.STABLE_CYC(2_500_000)) u_db[3:0] (
        .clk(sys_clk), .rst_n(rst_n),
        .btn_i(btn), .level_o(btn_level), .pulse_o(btn_pulse)
    );

    // ==================================================================
    // 3) 模式 FSM + 速度�?(1..8) + 使能 + 手动 duty 偏移
    // ==================================================================
    logic [1:0] mode_r;      // 0常亮 1呼吸 2闪烁 3手动PWM
    logic [2:0] speed_r;     // 档位 1..8
    logic       en_r;        // BTN3 使能
    logic [7:0] duty_man_r;  // BTN2 偏移:0/16/32/.../240 循环

    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_r     <= 2'd1;    // 上电默认呼吸
            speed_r    <= 3'd2;
            en_r       <= 1'b1;
            duty_man_r <= 8'd0;
        end else begin
            if (btn_pulse[0]) mode_r     <= mode_r + 2'd1;          // 0�?1�?2�?3�?0 自然回绕
            if (btn_pulse[1]) speed_r    <= (speed_r == 3'd7) ? 3'd1 : speed_r + 3'd1;
            if (btn_pulse[2]) duty_man_r <= duty_man_r + 8'd16;     // 自然回绕
            if (btn_pulse[3]) en_r       <= ~en_r;
        end
    end

    // 速度仲裁:VIO 覆盖(vio_speed!=0 时生�?)
    logic [2:0] speed_eff;
    assign speed_eff = (vio_speed != 3'd0) ? vio_speed : speed_r;

    // ==================================================================
    // 4) 呼吸三角�?(模式1) / 闪烁方波(模式2)
    //    step_tick 间隔 = 2^(22-speed) �?:
    //      speed=1�?16.8ms/�?(呼吸周期�?8.6s)  speed=2�?8.4ms(�?4.3s)
    //      speed=4�?2.1ms(�?1.1s)              speed=8�?131µs(�?67ms)
    //    闪烁:�? 64 �? step_tick 翻转 �? speed=2 时约 0.93Hz
    // ==================================================================
    logic [21:0] step_cnt;
    logic [21:0] step_interval;
    logic        step_tick;
    logic [7:0]  tri_cnt;
    logic        tri_dir;      // 0=递增 1=递减
    logic [5:0]  blink_div;
    logic        blink_val;

    assign step_interval = 22'd1 << (6'd22 - {3'd0, speed_eff}); // speed�?1..8 �? 2^21..2^14
    assign step_tick     = (step_cnt == step_interval - 22'd1);

    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) step_cnt <= '0;
        else        step_cnt <= step_tick ? '0 : step_cnt + 22'd1;
    end

    // 三角�? 0�?255 �?�?(�?/谷各停留 1 �?,避免抖动)
    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            tri_cnt <= 8'd0;
            tri_dir <= 1'b0;
        end else if (step_tick) begin
            if (!tri_dir) begin
                if (tri_cnt == 8'd255) tri_dir <= 1'b1;
                else                   tri_cnt  <= tri_cnt + 8'd1;
            end else begin
                if (tri_cnt == 8'd0)   tri_dir <= 1'b0;
                else                   tri_cnt  <= tri_cnt - 8'd1;
            end
        end
    end

    // 闪烁:0/255 切换
    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            blink_div <= '0;
            blink_val <= 1'b0;
        end else if (step_tick) begin
            blink_div <= blink_div + 6'd1;
            if (blink_div == 6'd63) blink_val <= ~blink_val;
        end
    end

    // ==================================================================
    // 5) 模式/duty 仲裁
    // ==================================================================
    logic [1:0] mode_sel;
    assign mode_sel = vio_mode_ovr_en ? 2'd3 : mode_r;   // VIO 可在线强切模�?3

    logic [7:0] duty_auto;   // 模式0/1/2 的自动占空比
    always_comb begin
        case (mode_sel)
            2'd0:    duty_auto = 8'hFF;                      // 常亮
            2'd1:    duty_auto = tri_cnt;                    // 呼吸(三角�?)
            2'd2:    duty_auto = blink_val ? 8'hFF : 8'h00;  // 闪烁(方波)
            default: duty_auto = 8'h00;                      // 模式3 �? �? vio_duty
        endcase
    end

    logic [7:0] duty_sel;
    // 模式3:VIO 基准 + BTN2 偏移(duty_man_r 默认 0,即纯 vio_duty)
    assign duty_sel = (mode_sel == 2'd3) ? (vio_duty + duty_man_r) : duty_auto;

    assign vio_mode     = mode_sel;   // VIO 回读
    assign vio_duty_now = duty_sel;   // VIO 回读

    // ==================================================================
    // 6) PWM ×2 + 1Hz 心跳 + LED 拼装
    // ==================================================================
    logic en_eff;
    assign en_eff = en_r & vio_en;    // BTN3 �? VIO 使能相与

    logic pwm_out;
    pwm_gen #(.W(8)) u_pwm (
        .clk(sys_clk), .rst_n(rst_n),
        .en_i(en_eff), .duty_i(duty_sel), .pwm_o(pwm_out)
    );

    // led1:单引脚显示模�? �? PWM 亮度 4 �?(3F/7F/BF/FF �? 25/50/75/100%)
    //      真·独热另�? mode_oh,�? ILA/VIO 探针使用
    logic [3:0] mode_oh;
    logic       mode_pwm;
    assign mode_oh = 4'b0001 << mode_sel;
    pwm_gen #(.W(8)) u_pwm_mode (
        .clk(sys_clk), .rst_n(rst_n),
        .en_i(1'b1), .duty_i({mode_sel, 6'b111111}), .pwm_o(mode_pwm)
    );

    // 1Hz 心跳:�? 62.5M �?(0.5s)翻转�?�? �? 全周�? 1s
    logic [30:0] hb_cnt;
    logic        hb;
    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            hb_cnt <= '0;
            hb     <= 1'b0;
        end else if (hb_cnt == 31'd62_500_000 - 1) begin
            hb_cnt <= '0;
            hb     <= ~hb;
        end else begin
            hb_cnt <= hb_cnt + 31'd1;
        end
    end

    assign led[0] = pwm_out;                   // PWM 输出(en=0 自动�?)
    assign led[1] = en_eff ? mode_pwm : 1'b0;  // 模式亮度指示(�?=�?)
    assign led[2] = hb;                        // 1Hz 心跳(永远活着,包括 en=0)
    assign led[3] = en_r;                      // BTN3 使能状�??

    // ==================================================================
    // 7) S5:VIO / ILA 例化(配好 IP 后打�?,并删除第1节的 initial 默认�?)
    // ==================================================================
     vio_0 u_vio (
         .clk        (sys_clk),
         .probe_out0 (vio_mode_ovr_en),  // 1bit : 1=VIO接管(强制模式3)
         .probe_out1 (vio_duty),         // 8bit : 模式3基准占空�?
         .probe_out2 (vio_en),           // 1bit : 全局使能
         .probe_out3 (vio_speed),        // 3bit : 速度覆盖(0=不覆�?)
         .probe_in0  (vio_mode),         // 2bit : 模式回读
         .probe_in1  (vio_duty_now)      // 8bit : duty回读
     );
     ila_0 u_ila (                     // 触发条件:probe1 == 4'h1(BTN0脉冲,任�?�一�?)
         .clk    (sys_clk),
         .probe0 (btn),        // [3:0] 原始按键(带抖�?)
         .probe1 (btn_pulse),  // [3:0] 消抖后干�?单脉�?
         .probe2 (duty_sel),   // [7:0] 生效占空�?
         .probe3 (pwm_out)     // [0]  PWM 输出
     );

endmodule
