import module namespace config = "http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";  
import module namespace load = "http://tools.aidinfolabs.org/api/load" at "../lib/load.xqm";  
import module namespace activity = "http://tools.aidinfolabs.org/api/activity" at "../lib/activity.xqm";  

declare variable $local:corpus external;
declare variable $local:host external;
declare variable $local:set external;
declare variable $local:mode external;

let $login := config:login()
let $sets := 
   if ($local:set ne "")
   then activity:activitySet($local:corpus,$local:set)
   else if ($local:host ne "")
   then activity:host-activitySets($local:corpus,$local:host)
   else activity:activitySets($local:corpus)
return load:download-activities($sets,<context><corpus>{$local:corpus}</corpus><mode>{$local:mode}</mode></context>)
