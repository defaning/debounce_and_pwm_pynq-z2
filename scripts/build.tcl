# =============================================================================
# build.tcl —— P1 按键消抖+PWM呼吸灯(PYNQ-Z2 xc7z020clg400-1, Vivado 2022.1)
# 母版: ../../docs/templates/build_template.tcl(已实板验证流程)
# S5 阶段: 用 /vivado-ip-configurator 生成 VIO/ILA 配置后替换 <TODO> 段
# =============================================================================
set script_dir [file normalize [file dirname [info script]]]
set base_dir   [file dirname $script_dir]
set proj_name  p1_debounce_pwm
set top_name   breathe_top
set proj_dir   [file join $base_dir vivado_proj]

set part xc7z020clg400-1

# ---- 引脚自检(本工程 XDC 用到的全部引脚) -----------------------------------
foreach pin {H16 R14 P14 N16 M14 D19 D20 L20 L19 M20 M19} {
    if {[llength [get_package_pins -quiet $pin]] != 1} {
        error "PIN-CHECK: $pin is NOT a valid package pin on $part"
    }
}
puts "PIN-CHECK: all pins valid on $part"

create_project -force $proj_name $proj_dir -part $part
add_files -fileset sources_1 [glob -directory [file join $base_dir rtl] *.sv]
add_files -fileset constrs_1 [glob -directory [file join $base_dir constr] *.xdc]
set_property top $top_name [current_fileset]

# ---- VIO: 2 in(mode/duty_now) + 4 out(ovr_en/duty/en/speed) ------------------
# TODO(S5): create_ip -name vio ... 按 README §5 探针表;要点:
#   C_PROBE_OUT0_INIT_VAL = 0x0  (mode_ovr_en)
#   C_PROBE_OUT1_INIT_VAL = 0x80 (duty)
#   C_PROBE_OUT2_INIT_VAL = 0x1  (en —— 上电必须使能!)
#   C_PROBE_OUT3_INIT_VAL = 0x2  (speed)

# ---- ILA: 4 探针 4/4/8/1, 深度 1024 -----------------------------------------
# TODO(S5): create_ip -name ila ... probe0=btn(4) probe1=btn_pulse(4)
#           probe2=duty_sel(8) probe3=pwm_out(1);C_EN_STRG_QUAL=1

# generate_target all [get_ips]

launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} { error "Synthesis failed" }
puts "BUILD:synth_1 done"

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} { error "Implementation failed" }
puts "BUILD:impl_1 done"

set run_dir [file join $proj_dir $proj_name.runs impl_1]
set bit [glob -nocomplain -directory $run_dir *.bit]
set ltx [glob -nocomplain -directory $run_dir *.ltx]
if {[llength $bit] == 0} { error "No bitstream generated" }
puts "BUILD:BITSTREAM=[lindex $bit 0]"
puts "BUILD:LTX=[expr {[llength $ltx] ? [lindex $ltx 0] : "MISSING"}]"
puts "BUILD:DONE"
