# ===============================
# USM Cal for Puma7
# Ver 1.0.0: Initailize program
# ===============================

proc parameter {} {
	# package load
	package require Tk
	package require tile
	package require inifile
	
	set ::att 0
	set ::ns_power [list 17.9 18.1 18.0 18.3 18.6 18.6 18.4 18.6 18.6 18.5 18.5 18.7 18.8 18.5 18.7 18.7 18.8 18.8 18.7 18.5 18.5 18.4 18.5 18.5 18.4 18.7 18.7 18.6 18.8 19.2 19.2 19.0 19.6 19.3 19.4 19.0 19.2 19.0 19.4 19.3 19.0 18.9 18.9 19.4 19.4 19.2 19.4 18.9 18.6 19.2 19.1 19.1 19.2 19.3 19.3 19.0 19.0 19.0 19.6 19.1 19.1 18.8 18.6 19.0 19.1 19.0 19.1 19.1 18.8 19.1 19.7 20.1 19.8 19.1 19.3 19.6 19.3 19.2 19.1 19.3 19.4 19.7 19.3 19.0 19.6 19.2 19.2 18.9 19.0 19.2 19.1 19.2 19.3 19.4 19.5 19.5 19.3 19.8 19.4 19.4 19.4 19.3 19.5 19.1 19.2 19.5 19.3 19.1 19.1 19.4 19.2 19.1 19.3 19.2 19.5 19.4 19.3 19.2 19.8 19.5 19.4 19.5 19.4 19.7 19.8 19.5 19.2 19.2 19.8 19.6 19.5 20.1 19.7 19.5 19.5 19.6 19.6 19.3 19.4 19.5 19.2 19.6 19.5 19.3 19.8 19.5 19.8 20.0 19.7 19.6 19.5 19.7 19.6 19.4 19.6 19.5 19.7 20.0 19.7 19.3 19.5 19.8 19.8 19.7 19.9 19.5 19.6 19.4 19.4 19.4 19.4 19.8 19.5 19.6 19.4 19.7 19.5 19.5 19.3 19.6 19.6 19.5 19.5 19.6 19.5 19.8 19.8 19.8 19.8 19.7 19.7 20.3 19.9 19.8 19.8 19.9 19.7 20.2 20.2 19.8]
	
	set ::PATH [pwd]
	set ::version "1.0.0"
	set ::cm_ip "192.168.100.1"
	set ::cmDiplexerConfigSelected ".1.3.6.1.4.1.35604.2.2.1.46.1.6"
	set ::cmFactoryDbgBootEnable ".1.3.6.1.4.1.35604.2.1.28"
	set ::docsDevResetNow ".1.3.6.1.2.1.69.1.1.3"
	
	# source file
	load "$::PATH/lib/netsnmptcl.dll"
	load "$::PATH/lib/lpttcl.dll"
	load "$::PATH/lib/tclping.dll"
}

proc telnetOpen {telnetIp {port 23} {myaddress "" }} {

	if { [string length $myaddress] > 7 } {
		if { [catch { socket -myaddr $myaddress $telnetIp $port } channel] } {
			return 0
		}
	} else {
		if { [catch { socket $telnetIp $port } channel] } {
			return 0
		}
	}
	fconfigure $channel -blocking 0 -buffering line
	return $channel

}

proc promptwaitys { consoleid writein waitfor { wait_time 10 } { newline 1 } } {
	set line ""
	set start [ clock seconds ]
	# set aa [ read $consoleid ]
	# puts $aa
	if { $newline } { 
		if { [ catch { puts $consoleid $writein } ] } {
			return 0
		}
	} else {
		if { [ catch { puts -nonewline $consoleid $writein } ] } {
			return 0
		}
	}
	catch { flush $consoleid }
	set line ""
	set appline ""
	set line_count 0
	while {1} {
		Sleep 100
		if { [ clock seconds ] - $start > $wait_time } {
			return 0
		}
		catch { set line [ read $consoleid ] }
		### no scan
		if {$line=="" && $waitfor == "Try to lock on primary"} {
			incr line_count
			if {$line_count==10} {
				return 1
			}
		}
		$::resultlog insert end $line
		$::resultlog see end
		update
		append appline $line
		if { [ regexp "$waitfor" $appline ] } {
			return [ list 1 $appline ]
		}
		update
	}
}

proc now_short { } {
	return [clock format [clock seconds] -format "%Y%m%d-%H%M%S"]
}

proc Sleep {tt} {
	set cc 0
	after $tt {
		set cc 1
	}
	vwait cc	
}

proc check_link {sec} {
	set result 0
	set wait_link_start [clock seconds]
	set wait_link_end [clock seconds]
	
	while {[expr $wait_link_end - $wait_link_start] < $sec} {
		if { [ping $::cm_ip -timeout 1000 -count 1 -simple] == 1 } {
			set result 1
			break
		}
		set wait_link_end [clock seconds]
	}
	Sleep 10
	
	return $result
}

proc output_log {str} {
	$::resultlog insert end $str ::message
	puts $::logfd $str
	$::resultlog see end
	update
}

proc output_log_error {str} {
	$::resultlog insert end $str ::error
	puts $::logfd $str
	$::resultlog see end
	update
}

proc tel_end {} {
	catch {
		close $::fd
		close $logfd
	}
}

proc btn_fail {} {
	.f1.lbl_2 configure -text "Fail" -background #ff3328
	.f3.btn1 configure -state normal
}

proc btn_pass {} {
	.f1.lbl_2 configure -text "Pass" -background #0fbf1c
	.f3.btn1 configure -state normal
}

proc runcal {} {
	
	set re ""
	set maxatt 8
	
	set ::logfd [open "$::PATH/log/[now_short].txt" w+]
	
	.f3.btn1 configure -state disable
	.f1.lbl_2 configure -text "Run" -background #ffc488
	set ::start_time [clock seconds]
	$::resultlog delete 0.0 end
	
	output_log "Check CM link status\n"
	set result [check_link 150]
	if {$result == 0} {
		output_log_error "Check CM link Fail\n"
		btn_fail
		return 0
	}
	output_log "Check CM link pass\n"
	
	output_log "Set CM to DBG mode\n"
	if {[catch {snmp_set -r 0 -t 3 -Oqv $::cm_ip private $::cmFactoryDbgBootEnable.0 i 1} re]} {
		output_log_error "SNMP set DBG mode FAIL {$re})\n"
		btn_fail
		return 0
	}
	
	output_log "==========Start to test=============\n"
	output_log "Start time: [now_short]\n"
	output_log "ATT now is [lpt_rddata], and change to $::att\n"
	
	
	if {[catch {lpt_wrdata $::att} re]} {
		output_log_error "Fail to Set att to $::att\n"
		btn_fail
		return 0
	}
	
	output_log "------Open Telnet connect to UUT------\n"
	foreach index [list 1 2] usm_power [list 79 198] {
		set band_state 2
		switch -- $index {
			"1" {
				set usm_cmd_start "pwrSpectrumSetCmd 1 1 300 45000000 45000000 80000000 80 1 128"
				set usm_cmd_stop "pwrSpectrumSetCmd 1 0 300 45000000 45000000 80000000 80 1 128"
			}
			"2" {
				set usm_cmd_start "pwrSpectrumSetCmd 1 1 300 104500000 104500000 199000000 199 1 128"
				set usm_cmd_stop "pwrSpectrumSetCmd 1 0 300 104500000 104500000 199000000 199 1 128"
			}
		}
		
		output_log "Switch to Band$index\n"
		catch {snmp_set -r 0 -t 3 -Oqv $::cm_ip private $::cmDiplexerConfigSelected.$index i 1}
		catch {snmp_set -r 0 -t 3 -Oqv $::cm_ip private $::docsDevResetNow.0 i 1}
		output_log "Wait CM reboot....\n"
		Sleep 15000
		set result [check_link 150]
		if {$result == 0} {
			output_log_error "Wait reboot Fail\n"
			btn_fail
			return 0
		}
		
		
		catch {set band_state [snmp_get -r 1 -t 3 -Oqv $::cm_ip private $::cmDiplexerConfigSelected.$index]}
		if {$band_state != 1} {
			output_log_error "Switch Band Index Fail\n"
			btn_fail
			return 0
		}
		
		output_log "Tuner Band: $band_state\n"
		
		set ::fd [telnetOpen $::cm_ip]
		if {$::fd == 0} {
			output_log_error "Telnet connection fail\n"
			btn_fail
			return 0
		}
		fconfigure $::fd -blocking 0 -translation cr -buffering none

		if {![lindex [promptwaitys $::fd "root" "Enter Password:" 5] 0]} {
			output_log_error "Input Username Fail\n"
			btn_fail
			return 0
		}

		if {![lindex [promptwaitys $::fd "CBN" ">" 5] 0]} {
			output_log_error "Input Password Fail\n"
			btn_fail
			return 0
		}
		
		if {![lindex [promptwaitys $::fd "top" "mainMenu" 5] 0]} {
			output_log_error "Input top Fail\n"
			btn_fail
			return 0
		}
		
		# goto Test dir
		set dir_list [list top docsis "sc 0" Production]
		# set dir_list [list docsis "sc 0" Production Test]
		foreach dir $dir_list {
			if {![lindex [promptwaitys $::fd "$dir" ">" 5] 0]} {
				output_log_error "Input $dir Fail\n"
				btn_fail
				return 0
			}
		}
		
		output_log "Enter Upstream Monitoring Calibration Process\n"
		
		# goto Test dir
		set dir_list [list top docsis Production Test]
		# set dir_list [list docsis "sc 0" Production Test]
		foreach dir $dir_list {
			if {![lindex [promptwaitys $::fd "$dir" ">" 5] 0]} {
				output_log_error "Input $dir Fail\n"
				btn_fail
				return 0
			}
		}

		output_log "Enable testmode on cli\n"
		if {![lindex [promptwaitys $::fd "testmode" ">" 10] 0]} {
			output_log_error "Input testmode Fail\n"
			btn_fail
			return 0
		}

		after 3000

		if {![lindex [promptwaitys $::fd "Tuner" ">" 5] 0]} {
			output_log_error "Input Tuner Fail\n"
			btn_fail
			return 0
		}
		
		# Meas
		for {set att 0} {$att < $maxatt} {incr att} {
			# set att 1
			set usm_meas_[set att] [list]
			output_log "Start Calibration ATT:$att\n"
			
			if {![lindex [promptwaitys $::fd "$usm_cmd_start $att" ">" 5] 0]} {
				output_log_error "[ttime] Input pwrSpectrumSetCmd Start Fail"
				btn_fail
				return 0
			}

			after 5000

			set get_meas [promptwaitys $::fd "pwrSpectrumGetMeas 1" ">" 5]
			after 1000

			if {![lindex [promptwaitys $::fd "$usm_cmd_stop $att" ">" 5] 0]} {
				output_log_error "[ttime] Input pwrSpectrumSetCmd Stop Fail"
				btn_fail
				return 0
			}
			
			puts get_meas:$get_meas
			output_log "==============================================\n"
			foreach str [split $get_meas \n] {
				# puts $str
				if {[regexp -line {freq\[Hz\]=(.+) power\[dBmV\]=(.+)} $str match freq pow]} {
					output_log "freq\t$freq\tpow\t$pow\n"
					lappend usm_meas_[set att] $pow
				}
			}
			output_log "==============================================\n"
			
			set index 0
			foreach ns [lrange $::ns_power 0 $usm_power ] rep [set usm_meas_[set att]] {
				output_log "index $index: $rep - $ns:\t[expr $rep - $ns]\n"
				lappend cal_pow_85_$att [expr $rep - $ns]
				incr index
			}
		}
		
	}
	output_log "\n\nCalibration Completed\n"
	
	set endtime [clock seconds]
	output_log "[now_short] Testing is done.\n"
	output_log "Total spend time : [clock format [expr $endtime-$::start_time] -format "%M:%S"]\n"
	output_log "Pass"
	btn_pass
}


proc main_GUI {} {
	#Windows Size Setting
	wm title . "USM Cal for Puma7 Rev: $::version"
	set width [winfo screenwidth .]
	set heigh [winfo screenheight .]
	set user_width 800
	set user_heigh 550
	wm geometry . [set user_width]x[set user_heigh]+[expr [expr $width-$user_width]/2]+[expr [expr $heigh-$user_heigh]/2]
	wm resizable . 1 1 
	wm attributes . -alpha 0.95
	
	ttk::separator .sep1
	ttk::separator .sep2
	ttk::separator .sep3
	ttk::frame .f1
	ttk::labelframe .f2 -text "Result Log"
	ttk::frame .f3
	pack .sep1 -fill x
	pack .f1 -fill x -padx 5 -pady 5
	pack .sep2 -fill x
	pack .f2 -padx 5 -pady 5 -fill both -expand 1
	pack .sep3 -fill x
	pack .f3 -padx 5 -pady 5 -side bottom -fill x
	ttk::label .f1.lbl_1 -text "USM Calibration for Puma7" -width 40 -anchor center -font [font create -size 20 -family "Arial bold"]
	ttk::label .f1.lbl_2 -text "Ready" -anchor center -font [font create -size 20 -family "Arial bold"] -background #8ea8ff -relief groove -width 10
	pack .f1.lbl_1 -fill x -side left
	pack .f1.lbl_2 -padx 10 -anchor e
	
	set ::resultlog [text .f2.list -wrap none -relief flat -font "Arial 10 bold"]
	set sh [::ttk::scrollbar .f2.sh -orient horizontal -command [list $::resultlog xview]]
	set sv [::ttk::scrollbar .f2.sv -orient vertical   -command [list $::resultlog yview]]
	$::resultlog configure -yscrollcommand [list $sv set]
	$::resultlog configure -xscrollcommand [list $sh set]
	grid $::resultlog $sv -sticky "news"
	grid $sh -sticky "news"
	grid rowconfigure .f2 0 -weight 1
	grid columnconfigure .f2 0 -weight 1
	
	ttk::button .f3.btn1 -text "Run Cal" -command {runcal;tel_end}
	ttk::button .f3.btn2 -text "Exit" -command {tel_end;exit}
	pack .f3.btn2 .f3.btn1 -side right -padx 5
	
	$::resultlog tag configure ::title -font "Arial 12 bold" -foreground #002b6a
	$::resultlog tag configure ::message -font "Arial 10 bold" -foreground #0042ae
	$::resultlog tag configure ::error -font "Arial 10 bold" -foreground #f01800
}

parameter
main_GUI