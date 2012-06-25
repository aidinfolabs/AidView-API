import module namespace log ="http://kitwallace.me/log" at "/db/lib/log-2.xqm";

let $log := request:get-parameter("log",())
return
  log:archive($log)

