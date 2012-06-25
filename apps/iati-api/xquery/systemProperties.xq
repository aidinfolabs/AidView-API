element exist-db {
  element version {system:get-version()},
  element revision {system:get-revision()}, 
  element build {system:get-build()},
  element uptime-hours {days-from-duration(system:get-uptime())* 24 + hours-from-duration(system:get-uptime())},
  element active-instances {system:count-instances-active()},
  element available-instances {system:count-instances-available()},
  element max-instances {system:count-instances-max()},
  element memory-free {system:get-memory-free()},
  element memory-max {system:get-memory-max()},
  element memory-total {system:get-memory-total()},
  element modules {
  for $module in util:registered-modules() 
   return
    element module {$module}
  }
}




