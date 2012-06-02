element exist-db {
  element version {system:get-version()},
  element revision {system:get-revision()}, 
  element build {system:get-build()},
  element uptime-hours {days-from-duration(system:get-uptime())* 24 + hours-from-duration(system:get-uptime())},
  element active-instances {system:count-instances-active()},
  element available-instances {system:count-instances-available()},
  element max-instances {system:count-instances-max()},
  element memory-free {round(system:get-memory-free() div 1024) },
  element memory-max {round(system:get-memory-max() div 1024 )},
  element memory-total {round(system:get-memory-total() div 1024)},
  element modules {
  for $module in util:registered-modules() 
  order by $module
   return
    element module {$module}
  }
}




