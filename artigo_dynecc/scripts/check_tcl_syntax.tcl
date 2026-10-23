# Static Tcl parser completeness check; does NOT validate Cadence APIs.
foreach file $argv {
  set f [open $file r];set s [read $f];close $f
  if {![info complete $s]} {puts stderr "UNBALANCED: $file";exit 1}
  puts "TCL_BALANCED: $file"
}
