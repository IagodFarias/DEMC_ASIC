# ####################################################################

#  Created by Genus(TM) Synthesis Solution 21.10-p002_1 on Tue Sep 01 15:20:29 -03 2026

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design ecc_design

set_max_delay 5000 -from [list \
  [get_ports {data_in_left[0]}]  \
  [get_ports {data_in_left[1]}]  \
  [get_ports {data_in_left[2]}]  \
  [get_ports {data_in_left[3]}]  \
  [get_ports {data_in_left[4]}]  \
  [get_ports {data_in_left[5]}]  \
  [get_ports {data_in_left[6]}]  \
  [get_ports {data_in_left[7]}]  \
  [get_ports {data_in_left[8]}]  \
  [get_ports {data_in_left[9]}]  \
  [get_ports {data_in_left[10]}]  \
  [get_ports {data_in_left[11]}]  \
  [get_ports {data_in_left[12]}]  \
  [get_ports {data_in_left[13]}]  \
  [get_ports {data_in_left[14]}]  \
  [get_ports {data_in_left[15]}]  \
  [get_ports {data_in_right_up[0]}]  \
  [get_ports {data_in_right_up[1]}]  \
  [get_ports {data_in_right_up[2]}]  \
  [get_ports {data_in_right_up[3]}]  \
  [get_ports {data_in_right_up[4]}]  \
  [get_ports {data_in_right_up[5]}]  \
  [get_ports {data_in_right_up[6]}]  \
  [get_ports {data_in_right_up[7]}]  \
  [get_ports {data_in_right_up[8]}]  \
  [get_ports {data_in_right_up[9]}]  \
  [get_ports {data_in_right_up[10]}]  \
  [get_ports {data_in_right_up[11]}]  \
  [get_ports {data_in_right_up[12]}]  \
  [get_ports {data_in_right_up[13]}]  \
  [get_ports {data_in_right_up[14]}]  \
  [get_ports {data_in_right_up[15]}]  \
  [get_ports {data_in_right_down[0]}]  \
  [get_ports {data_in_right_down[1]}]  \
  [get_ports {data_in_right_down[2]}]  \
  [get_ports {data_in_right_down[3]}]  \
  [get_ports {data_in_right_down[4]}]  \
  [get_ports {data_in_right_down[5]}]  \
  [get_ports {data_in_right_down[6]}]  \
  [get_ports {data_in_right_down[7]}]  \
  [get_ports {data_in_right_down[8]}]  \
  [get_ports {data_in_right_down[9]}]  \
  [get_ports {data_in_right_down[10]}]  \
  [get_ports {data_in_right_down[11]}]  \
  [get_ports {data_in_right_down[12]}]  \
  [get_ports {data_in_right_down[13]}]  \
  [get_ports {data_in_right_down[14]}]  \
  [get_ports {data_in_right_down[15]}]  \
  [get_ports {sel[2]}]  \
  [get_ports {sel[1]}]  \
  [get_ports {sel[0]}]  \
  [get_ports chip_sel] ] -to [list \
  [get_ports {data_out_right_up[0]}]  \
  [get_ports {data_out_right_up[1]}]  \
  [get_ports {data_out_right_up[2]}]  \
  [get_ports {data_out_right_up[3]}]  \
  [get_ports {data_out_right_up[4]}]  \
  [get_ports {data_out_right_up[5]}]  \
  [get_ports {data_out_right_up[6]}]  \
  [get_ports {data_out_right_up[7]}]  \
  [get_ports {data_out_right_up[8]}]  \
  [get_ports {data_out_right_up[9]}]  \
  [get_ports {data_out_right_up[10]}]  \
  [get_ports {data_out_right_up[11]}]  \
  [get_ports {data_out_right_up[12]}]  \
  [get_ports {data_out_right_up[13]}]  \
  [get_ports {data_out_right_up[14]}]  \
  [get_ports {data_out_right_up[15]}]  \
  [get_ports {data_out_right_down[0]}]  \
  [get_ports {data_out_right_down[1]}]  \
  [get_ports {data_out_right_down[2]}]  \
  [get_ports {data_out_right_down[3]}]  \
  [get_ports {data_out_right_down[4]}]  \
  [get_ports {data_out_right_down[5]}]  \
  [get_ports {data_out_right_down[6]}]  \
  [get_ports {data_out_right_down[7]}]  \
  [get_ports {data_out_right_down[8]}]  \
  [get_ports {data_out_right_down[9]}]  \
  [get_ports {data_out_right_down[10]}]  \
  [get_ports {data_out_right_down[11]}]  \
  [get_ports {data_out_right_down[12]}]  \
  [get_ports {data_out_right_down[13]}]  \
  [get_ports {data_out_right_down[14]}]  \
  [get_ports {data_out_right_down[15]}]  \
  [get_ports {data_out_left[0]}]  \
  [get_ports {data_out_left[1]}]  \
  [get_ports {data_out_left[2]}]  \
  [get_ports {data_out_left[3]}]  \
  [get_ports {data_out_left[4]}]  \
  [get_ports {data_out_left[5]}]  \
  [get_ports {data_out_left[6]}]  \
  [get_ports {data_out_left[7]}]  \
  [get_ports {data_out_left[8]}]  \
  [get_ports {data_out_left[9]}]  \
  [get_ports {data_out_left[10]}]  \
  [get_ports {data_out_left[11]}]  \
  [get_ports {data_out_left[12]}]  \
  [get_ports {data_out_left[13]}]  \
  [get_ports {data_out_left[14]}]  \
  [get_ports {data_out_left[15]}]  \
  [get_ports {flag[0]}]  \
  [get_ports {flag[1]}]  \
  [get_ports {flag[2]}]  \
  [get_ports {chip_sel_out[1]}]  \
  [get_ports {chip_sel_out[0]}] ]
set_clock_gating_check -setup 0.0 
