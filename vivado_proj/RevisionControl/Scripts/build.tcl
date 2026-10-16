#*******************************************************************************
# build.tcl - Project Recreation Script
# Generated: Fri Oct 16 19:35:15 2026
# Original Project: project_1
#*******************************************************************************

set script_dir [file dirname [file normalize [info script]]]
set base_dir [file dirname $script_dir]
set proj_name project_1

#─────────────────────────────────────────────────────────────────────────────────
# Step 1: Create Project
#─────────────────────────────────────────────────────────────────────────────────
# NOTE (release edit): generated script used "." (CWD) as project dir, which would
# clobber the live project if run from vivado_proj/. Created under rebuild/ instead.
set rebuild_dir [file normalize [file join $base_dir .. rebuild]]
create_project project_1 $rebuild_dir -part xc7z020clg400-1 -force
set_property BOARD_PART {tul.com.tw:pynq-z2:part0:1.0} [current_project]

#─────────────────────────────────────────────────────────────────────────────────
# Step 2: Add RTL Sources
#─────────────────────────────────────────────────────────────────────────────────
# Local sources �? import into project for full portability
set rtl_files {}
catch {set rtl_files [glob $base_dir/Sources/RTL/*]}
if {[llength $rtl_files] > 0} {
    import_files $rtl_files
}

# Remote sources �? referenced in-place at their original absolute location
catch {add_files -quiet [file normalize "$base_dir/../../rtl/debounce.sv"]}
catch {add_files -quiet [file normalize "$base_dir/../../rtl/pwm_gen.sv"]}
catch {add_files -quiet [file normalize "$base_dir/../../rtl/breathe_top.sv"]}
catch {add_files -quiet [file normalize "$base_dir/../../rtl/edge_detect.sv"]}
catch {add_files -quiet [file normalize "$base_dir/../../sim/tb_debounce.sv"]}
catch {add_files -quiet [file normalize "$base_dir/../../sim/tb_pwm.sv"]}

#─────────────────────────────────────────────────────────────────────────────────
# Step 3: Add Constraint Files
#─────────────────────────────────────────────────────────────────────────────────
set xdc_files {}
catch {set xdc_files [glob $base_dir/Sources/Constraints/*.xdc]}
# Include NoC constraints if present
catch {lappend xdc_files {*}[glob $base_dir/Sources/NoC/*.xdc]}
if {[llength $xdc_files] > 0} {
    import_files -fileset constrs_1 $xdc_files
}
# Remote constraints �? referenced in-place at their original absolute location
catch {add_files -quiet -fileset constrs_1 [file normalize "$base_dir/../../constr/pynqz2_p1.xdc"]}


#─────────────────────────────────────────────────────────────────────────────────
# Step 4: Add Simulation Files
#─────────────────────────────────────────────────────────────────────────────────
set sim_files {}
catch {set sim_files [glob $base_dir/Sources/Simulation/*]}
if {[llength $sim_files] > 0} {
    import_files -fileset sim_1 $sim_files
}
# Remote simulation files �? referenced in-place at their original absolute location
catch {add_files -quiet -fileset sim_1 [file normalize "$base_dir/../../rtl/debounce.sv"]}
catch {add_files -quiet -fileset sim_1 [file normalize "$base_dir/../../rtl/pwm_gen.sv"]}
catch {add_files -quiet -fileset sim_1 [file normalize "$base_dir/../../rtl/breathe_top.sv"]}
catch {add_files -quiet -fileset sim_1 [file normalize "$base_dir/../../rtl/edge_detect.sv"]}
catch {add_files -quiet -fileset sim_1 [file normalize "$base_dir/../../sim/tb_debounce.sv"]}
catch {add_files -quiet -fileset sim_1 [file normalize "$base_dir/../../sim/tb_pwm.sv"]}


#─────────────────────────────────────────────────────────────────────────────────
# Step 5: Add Data Files (Memory init, config, etc.)
#─────────────────────────────────────────────────────────────────────────────────
set data_files {}
catch {set data_files [glob $base_dir/Sources/Data/*]}
if {[llength $data_files] > 0} {
    import_files $data_files
}
# Remote data files �? referenced in-place at their original absolute location


#─────────────────────────────────────────────────────────────────────────────────
# Step 6: Recreate IP Cores
#─────────────────────────────────────────────────────────────────────────────────
set ip_tcls {}
catch {set ip_tcls [glob $base_dir/Sources/IP/*.tcl]}
foreach ip_tcl $ip_tcls {
    source $ip_tcl
}

# Create OOC synthesis runs for standalone IPs (outside Block Designs)
set standalone_ips [get_ips]
foreach ip $standalone_ips {
    set is_bd [get_property IS_BD_CONTEXT $ip]
    if {$is_bd ne "1" && $is_bd ne "true"} {
        catch {create_ip_run [get_ips [get_property NAME $ip]]}
    }
}

#─────────────────────────────────────────────────────────────────────────────────
# Step 7: Recreate Block Designs
# CRITICAL: BDC child BDs must be sourced BEFORE parent BDs that instantiate them.
# For DFX: RM Block Designs are skipped here �? they are added to RM filesets in
#          Step 12 (dfx_define_partition) to prevent them from becoming independent BDs.
#─────────────────────────────────────────────────────────────────────────────────
set _preserved_bd_names [list ]
set bd_tcls {}
catch {set bd_tcls [glob $base_dir/Sources/BD/*.tcl]}
foreach bd_tcl $bd_tcls {
    set bd_basename [file rootname [file tail $bd_tcl]]
    # Preserved BDs never get a Sources/BD/*.tcl written at export time (see
    # the add_files+.gen-restore path below), so this glob naturally never
    # sees them -- no skip needed here.
    set bd_is_rm_owned 0
    if {[info exists _rm_owned_bd_names]} {
        set bd_is_rm_owned [expr {[lsearch $_rm_owned_bd_names $bd_basename] >= 0}]
    }
    if {$bd_is_rm_owned} {
        puts "  Skipping BD (RM-owned): $bd_basename"
    } else {
        source $bd_tcl
        if {[catch {validate_bd_design -force -design $bd_basename} _vbd_err]} {
            puts "  WARNING: validate_bd_design reported an error for $bd_basename: $_vbd_err"
            puts "  This is usually caused by locked/out-of-date IPs in the BD."
            puts "  On the ORIGINAL project: open_bd_design ${bd_basename}.bd; report_ip_status"
            puts "  then upgrade_ip the flagged IPs and re-run this export."
            puts "  NOTE: later commands (e.g. make_wrapper) may fail with 'failed due to"
            puts "  earlier errors' even though THIS is the real root cause."
        }
        catch {save_bd_design [get_bd_designs -quiet $bd_basename]}
    }
}
# Preserved BDs (remote cache mode): add_files their .bd restored from the cache
# in Step 1c, relying on the .gen restored there too to avoid regeneration.
# Step 1c already guarantees each preserved BD's source exists (it errors out
# the whole build otherwise), so no existence check is needed here.
array set _preserved_bd_rel_dir {}
foreach _bd_name $_preserved_bd_names {
    set _preserved_bd_src [file join ${proj_name}.srcs $_preserved_bd_rel_dir($_bd_name) "${_bd_name}.bd"]
    add_files -norecurse $_preserved_bd_src
    catch {generate_target all [get_files ${_bd_name}.bd]}
    catch {open_bd_design [get_files ${_bd_name}.bd]}
    catch {validate_bd_design -force -design $_bd_name}
    catch {save_bd_design [get_bd_designs -quiet $_bd_name]}
}

#─────────────────────────────────────────────────────────────────────────────────
# Step 8: Recreate Block Design wrappers (only if wrapper was present in project)
#─────────────────────────────────────────────────────────────────────────────────
# No BD wrappers were present in the original project - skipping

#─────────────────────────────────────────────────────────────────────────────────
# Step 9: Generate BD Targets and Create BD IP OOC Runs
# NOTE: Only operate on top-level user BDs from sources_1 fileset.
#       Nested sub-designs (e.g., inside Versal CIPS) are auto-generated by
#       their parent IP and MUST NOT be generated independently.
#       Using FILE_TYPE filter + .srcs path check to exclude them.
#─────────────────────────────────────────────────────────────────────────────────
set bd_files {}
catch {set bd_files [get_files -filter {FILE_TYPE == "Block Designs"} -of_objects [get_filesets sources_1]]}
foreach bd $bd_files {
    set bd_norm [file normalize $bd]
    # Skip nested sub-designs in .gen/ (auto-generated by parent IPs like Versal CIPS)
    if {[string match "*/.gen/*" $bd_norm]} {
        puts "  Skipping nested sub-design: [file tail $bd]"
        continue
    }
    # Skip generated BDs
    if {[get_property IS_GENERATED $bd] eq "1"} {
        puts "  Skipping generated BD: [file tail $bd]"
        continue
    }
    puts "  Generating targets for: [file tail $bd]"
    if {[catch {generate_target all $bd} _gt_err]} {
        puts "  ERROR: generate_target failed for [file tail $bd]: $_gt_err"
        puts "  Check the ERROR/CRITICAL WARNING lines just above for the real root"
        puts "  cause. Two known classes seen in this skill's own validation:"
        puts "    1) Debug-net (mark_debug/ILA) connections routed through a Block"
        puts "       Design Container failing to resolve on a freshly recreated"
        puts "       design ('Could not find the cell' errors) -- not an export"
        puts "       issue. Workaround: remove debug cores from the BD before"
        puts "       export, or manually regenerate targets for [file tail $bd]"
        puts "       in the GUI."
        puts "    2) A NoC memory-controller PHY IP (e.g. noc_mc_ddr5_phy_v1_0)"
        puts "       failing to generate simulation BFM outputs due to a missing"
        puts "       file under this Vivado install's own"
        puts "       data/ip/xilinx/<ip>/hdl/bfm/ tree ('Failed to copy file ..."
        puts "       it does not exist' CRITICAL WARNING) -- a Vivado installation"
        puts "       gap, not something export/rebuild can fix; report it to your"
        puts "       Vivado install owner."
    }
}

# Create OOC runs for IPs within top-level Block Designs only
foreach bd $bd_files {
    set bd_norm [file normalize $bd]
    if {[string match "*/.gen/*" $bd_norm]} { continue }
    if {[get_property IS_GENERATED $bd] eq "1"} { continue }
    catch {create_ip_run [get_ips -of_objects [get_files $bd]]}
}

#─────────────────────────────────────────────────────────────────────────────────
# Step 10: Add Hook Scripts to utils_1 fileset
#─────────────────────────────────────────────────────────────────────────────────
set hook_scripts {}
catch {set hook_scripts [glob $base_dir/Sources/Scripts/*.tcl]}
if {[llength $hook_scripts] > 0} {
    import_files -fileset utils_1 $hook_scripts
}

#─────────────────────────────────────────────────────────────────────────────────
# Step 11: Apply Captured Project Settings
#─────────────────────────────────────────────────────────────────────────────────
source $script_dir/project_settings.tcl
update_compile_order -fileset sources_1

#─────────────────────────────────────────────────────────────────────────────────
# Step 11b: Restore fileset source ordering (if captured)
#─────────────────────────────────────────────────────────────────────────────────
proc _rc_restore_fileset_order {fileset_name ordered_tails} {
    if {[llength [get_filesets -quiet $fileset_name]] == 0} { return }
    set last_file ""
    foreach tail $ordered_tails {
        set match {}
        catch {set match [get_files -quiet -of_objects [get_filesets $fileset_name] -filter "NAME =~ *${tail}"]}
        if {[llength $match] == 0} { continue }
        set f [lindex $match 0]
        if {$last_file eq ""} {
            catch {reorder_files -fileset $fileset_name -front $f}
        } else {
            catch {reorder_files -fileset $fileset_name -after $last_file $f}
        }
        set last_file $f
    }
    catch {update_compile_order -fileset $fileset_name}
}

_rc_restore_fileset_order constrs_1 pynqz2_p1.xdc
_rc_restore_fileset_order ila_0 {ila_0.xci ila_v6_2_changelog.txt ila_impl.xdc ila_0.veo ila_0.v ila_0.dcp ila_0_stub.v ila_0_stub.vhdl ltlib_v1_0_0_ver.vh ltlib_v1_0_0_lib_fn.vh xsdbs_v1_0_2_i2x.vh xsdbs_v1_0_2_in.vh xsdbm_v3_0_0_i2x.vh xsdbm_v3_0_0_in.vh xsdbm_v3_0_0_icn.vh xsdbm_v3_0_0_bs.vh xsdbm_v3_0_0_bs_ext.vh xsdbm_v3_0_0_bs_core.vh xsdbm_v3_0_0_bs_core_ext.vh xsdbm_v3_0_0_bs_ports.vh xsdbm_v3_0_0_bsid_ports.vh xsdbm_v3_0_0_bsid_vec_ports.vh xsdbm_v3_0_0_bs_vec.vh xsdbm_v3_0_0_bs_core_vec.vh xsdbm_v3_0_0_sl_prt_map.vh xsdbm_v3_0_0_id_map.vh xsdbm_v3_0_0_id_vec_map.vh ila_v6_2_12_ila_ver.vh ila_v6_2_12_ila_in.vh ila_v6_2_12_ila_param.vh ila_v6_2_12_ila_lparam.vh ila_v6_2_12_ila_lib_fn.vh ila.xdc ila_0_ooc.xdc ila_0.v}
_rc_restore_fileset_order sim_1 {tb_debounce.sv tb_pwm.sv}
_rc_restore_fileset_order sources_1 {debounce.sv pwm_gen.sv breathe_top.sv edge_detect.sv}
_rc_restore_fileset_order utils_1 breathe_top.dcp
_rc_restore_fileset_order vio_0 {vio_0.xci vio_v3_0_changelog.txt vio_0.vho vio_0.veo vio_0.v vio_0.dcp vio_0_stub.v vio_0_stub.vhdl ltlib_v1_0_0_ver.vh ltlib_v1_0_0_lib_fn.vh xsdbs_v1_0_2_i2x.vh xsdbs_v1_0_2_in.vh vio_0.xdc vio_0.v vio_0_ooc.xdc}

#─────────────────────────────────────────────────────────────────────────────────
# Step 13: Finalize Project
#─────────────────────────────────────────────────────────────────────────────────
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "──────────────────────────────────────────────────────────────────────────"
puts "Project recreated successfully!"
puts "──────────────────────────────────────────────────────────────────────────"
