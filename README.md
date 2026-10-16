# P1 · 按键消抖 + PWM 呼吸灯控制器

> **难度 ★ 入门 · 建议周期 2~3 天**
> 本项目是整个训练营的"全流程首航":第一次把 8 个技能从头到尾走一遍。
> 功能虽简单,但消抖电路和 PWM 是**每一块产品板都有的真实电路**——
> 你写下的每一个模块,P5 都会直接复用。

---

## 1. 功能定义(像产品一样写清楚)

1. 4 个按键 `btn[3:0]` 经**消抖 + 上升沿检测**后:
   - BTN0:切换模式(`0`=常亮 `1`=呼吸 `2`=闪烁 `3`=PWM 手动);
   - BTN1:呼吸/闪烁速度 ±1 档(内部档位 1~8);
   - BTN2:手动 PWM 占空比 +16(回绕);
   - BTN3:全局使能开关(关=全灭)。
2. 模式 3 下,占空比由 **VIO** 在线改(不重新综合);其他模式下占空比自动生成。
3. `led[3:0]`:LED0 显示 PWM 输出;LED1 显示当前模式(独热);LED2 = 1Hz 心跳(证明设计活着);
   LED3 显示 BTN3 使能状态。
4. ILA:在**按键消抖输出脉冲**上触发,抓消抖前后波形(原始抖动 vs 干净单脉冲)。

## 2. 你将练到的技能

| 阶段 | 技能 | 本项目的练习点(第一次) |
|---|---|---|
| S0 | vivado-revision-control | 建仓、.gitignore 排除 vivado_proj、首个 commit |
| S2 | vivado-rtl-lint | 看懂分级报告;体会"未用位""位宽截断"长什么样 |
| S3 | vivado-rtl-elaboration-analysis | 第一次读 synth elaborate 警告 |
| S4 | vivado-simulate-rtl | 自校验 TB:抖动激励 → 断言"只出 1 个脉冲" |
| S5 | vivado-ip-configurator | VIO(模式/占空比)+ ILA(探针表见 §6) |
| S6 | vivado-timing-methodology-checks | create_clock 正确性、无 unconstrained 路径 |
| S7 | hw-vio-debug → hw-ila-debug | VIO 改占空比;ILA 在按键事件触发抓波形 |

## 3. 系统框图

```
              125 MHz (H16)
                  │
        ┌─────────▼─────────┐
btn[3:0]│  debounce ×4      │  消抖: 20 ms 计数确认
───────►│  (DEBOUNCE_MS=20) │──── pulse[3:0] ───┐
        └───────────────────┘                   │
                                                  ▼
        ┌─────────────────────────────────────────────┐      ┌─────────┐
sw[1:0] │              breathe_top (FSM)               │─────►│ led[3:0]│
───────►│  模式机 + 速度档 + 三角波/呼吸波发生器          │      └─────────┘
        │  duty[7:0] ──► pwm_gen ──► pwm_out            │
        └───────▲───────────────────────────────────────┘
                │ mode_sel / duty_ovr / en
        ┌───────┴────────┐
        │ VIO (vio_0)    │  ← S7 上板在线改
        └────────────────┘
                ▲
        ┌───────┴────────┐
        │ ILA (ila_0)    │  ← 触发: pulse[0] 上升沿;抓 btn_raw/pulse/duty/pwm_out
        └────────────────┘
```

## 4. 模块规格与接口(骨架已给,函数体自己写)

| 文件 | 模块 | 要点 |
|---|---|---|
| `rtl/debounce.sv` | `debounce #(.STABLE_CYC)` | 20ms@125MHz=2_500_000 拍;输出 `pulse`(稳定后**单拍**脉冲)。对照 OpenRTLSet/020 |
| `rtl/edge_detect.sv` | `edge_detect #(.EDGES)` | 电平→脉冲;EDGES="RISE"/"FALL"/"BOTH" |
| `rtl/pwm_gen.sv` | `pwm_gen #(.W=8)` | duty/256 占空比;输出寄存器化(利于 IO timing) |
| `rtl/breathe_top.sv` | 顶层 | 模式 FSM + 速度档 + 三角波;VIO 覆盖与 ILA 探针全在这里 |

## 5. 分步任务书(S0~S7)

### S0 · 建仓(vivado-revision-control)
- 在 `P1_debounce_pwm/` 内 git init;.gitignore 必须排除 `vivado_proj/`(让 skill 生成);
- 首提交只有 `README.md rtl/ sim/ constr/ scripts/`;提交信息:`P1: scaffold (S0)`。

### S1 · 写代码
- 按骨架补全 4 个模块。**约定**:全部同步复位(`rst_n`,低有效)、全部同一时钟、显式初值。

### S2 · lint(vivado-rtl-lint)
- 触发句:"用 vivado-rtl-lint 检查 P1_debounce_pwm/rtl 全部文件,逐条解释并给修复";
- **故意埋雷自测**(埋完扫,扫完改回):在 `breathe_top` 写一个无 else 的组合 if → 应报锁存器;
  `duty` 用 8 位却比较 9 位常量 → 应报位宽问题;
- 报告解读存 `docs/lint_round1.md`(3~5 行:问题/为什么/怎么修)。

### S3 · elaboration(vivado-rtl-elaboration-analysis)
- 先跑综合(`launch_runs synth_1`),把日志喂给 skill;
- 重点看:`[Synth 8-3331]` 端口未连接、参数宽度、多驱动;
- 解读存 `docs/elab_round1.md`。

### S4 · 仿真(vivado-simulate-rtl)——本项目核心练习
- `sim/tb_debounce.sv`(骨架已给):构造抖动波形——
  稳定前给 3~5 段随机宽度(1~50 万拍)的毛刺,然后稳定 20ms;
  **断言**:整个过程中 `pulse` 恰好出现 1 拍,且出现在稳定窗之后;
- `sim/tb_pwm.sv`:duty=0 → 输出恒 0;duty=255 → 255/256 为高;duty=128 → 半程;
  每档连续抓 2 个 PWM 周期数高电平拍数比对;
- 让 skill 跑并汇总:PASS 判定必须来自 `TB-RESULT: PASS` 机读行。

### S5 · IP(vivado-ip-configurator)
按下面探针表让 skill 生成配置,贴进 `scripts/build.tcl`:

**VIO(2 入 4 出)**
| 探针 | 方向/宽度 | 初值 | 含义 |
|---|---|---|---|
| `vio_mode_ovr_en` | out/1 | 0x0 | 1=VIO 直接指定模式 |
| `vio_duty` | out/8 | 0x80 | 模式 3 的手动占空比 |
| `vio_en` | out/1 | 0x1 | 全局使能(**初值 1,不能是 0**,否则上板全灭误判死机)|
| `vio_speed` | out/3 | 0x2 | 速度档覆盖 |
| `vio_mode` | in/2 | — | 回读当前模式 |
| `vio_duty_now` | in/8 | — | 回读当前生效占空比 |

**ILA(4 探针,深度 1024 即可)**
| 探针 | 宽度 | 触发用法 |
|---|---|---|
| `probe_btn_raw` | 4 | 原始按键(抖动原貌) |
| `probe_pulse` | 4 | **触发源**:`pulse[0]==1` 上升沿 |
| `probe_duty` | 8 | 当前占空比 |
| `probe_pwm_out` | 1 | PWM 输出 |

### S6 · 时序(vivado-timing-methodology-checks)
- 综合后跑 UG906 检查;本项目单时钟,预期违规极少——**这是建立"干净基线"的机会**;
- 验收:`report_timing_summary` WNS ≥ 0 且 **unconstrained paths = 0**(VIO/ILA 的 JTAG 时钟
  会有例外,读懂 skill 对这些例外的解释,记录进 docs/timing_round1.md)。

### S7 · 上板(hw-vio-debug → hw-ila-debug)
1. 烧 bit(确认 .bit+.ltx 成对);
2. **VIO 三连**(触发句照抄 docs/01_skill_map.md):
   - 读 `vio_mode`、`vio_duty_now` 确认设计活着(LED2 心跳 1Hz 也应在闪);
   - 驱动 `vio_mode_ovr_en=1, vio_duty=0x10` → LED0 应明显变暗;
   - 驱动 `vio_duty=0xF0` → 变亮;
3. **ILA 抓按键**:设触发 `probe_pulse[0]` 上升沿 → arm → 按 BTN0 → 上传波形;
   **纸面预期**:btn_raw 上有 >1ms 的毛刺簇,pulse 上只有干净 1 拍,duty 随模式切换跳变;
4. 把 ILA 抓到的波形导出 CSV 存 `docs/hw_ila_btn.csv`,写 5 行解读;
5. `git tag p1-v1.0`,commit 所有 docs。

## 6. 验收 checklist(全部满足才算完成)

- [ ] git 仓库干净:`git status` 无未跟踪的 vivado_proj 产物
- [ ] lint 无 Critical;豁免有记录(docs/lint_waiver.md)
- [ ] elaboration 无未解释的 Critical Warning
- [ ] 两个 TB 均 `TB-RESULT: PASS`
- [ ] WNS ≥ 0,unconstrained paths 有逐条解释
- [ ] 上板:VIO 改占空比 LED 立即响应;ILA 成功抓到"毛刺→单脉冲"对比波形
- [ ] tag `p1-v1.0` 已打;docs/ 下 5 份过程记录齐全

## 7. 常见坑(30 年经验,先踩后看)

1. **消抖计数器位宽不够**:20ms@125MHz 需要 22 位(2.5e6 < 2^22);用 20 位会在 16ms 处回绕,产生"有时消抖成功有时失败"的灵异现象。
2. **pulse 生成写成电平**:输出若不是单拍脉冲,BTN0 按住一次会连跳多个模式——ILA 一抓便知。
3. **VIO 使能初值 0**:上板后设计"全灭",你会以为 bit 没烧进去。复位类/使能类探针初值必须让设计上电即工作。
4. **PWM 输出没寄存**:组合输出直接出 IO,IO timing 变差,S6 方法学会提示 IOB 寄存。
5. **XDC 端口名与 RTL 不一致**:`led[0]` 写成 `led0` → DRC 报 unconstrained port,且该引脚悬浮。

## 8. 进阶挑战(可选)

- 用 **RGB LED(阴极驱动,输出 0 点亮)** 做三通道 PWM:呼吸颜色在 RGB 色环上旋转;
  XDC 段已在 master 里,注意极性反转;
- 把消抖参数 `STABLE_CYC` 改成从 VIO 在线可调(2ms/5ms/10ms/20ms 四档),ILA 验证不同档位下的响应;
- 用 `vio_speed` 覆盖与 BTN1 加减档做"仲裁"(VIO 优先 or 按键优先),用 ILA 抓仲裁切换瞬间。
