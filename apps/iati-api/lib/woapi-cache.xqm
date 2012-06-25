module namespace iati-cache = "http://kitwallace.me/iati-cache";

import module namespace iati-wo = "http://kitwallace.me/iati-wo" at "../lib/iati-wo-6.xqm";
import module namespace log = "http://kitwallace.me/log" at "/db/lib/log.xqm";
import module namespace json="http://kitwallace.me/json" at "../lib/json.xqm";

declare function iati-cache:get() {
let $format := request:get-parameter("format","xml")
let $callback := request:get-parameter("callback",())
let $run-start := util:system-time()
let $qs := request:get-query-string()
let $key := util:hash($qs,"md5")
let $cache := doc("/db/cache/A.xml")/cache
let $cached-page := $cache/page[@key=$key]
let $page :=
 if (exists($cached-page)) 
 then $cached-page/node()
 else iati-wo:api()   
let $run-end := util:system-time()
let $run-milliseconds := (($run-end - $run-start) div xs:dayTimeDuration('PT1S'))  * 1000 
let $cacheit := 
   if ($run-milliseconds > 1000)
   then  
     update insert 
     element page {
         attribute key {$key},
         $page
     }
     into $cache
   else ()
let $logit := log:log-request("iati","api-c",concat("milliseconds=",$run-milliseconds))
return
  if ($format eq "xml")
  then $page
  else if ($format eq "json")
  then 
       let $option := util:declare-option ("exist:serialize","method=text media-type=application/json")
       let $header := response:set-header("Access-Control-Allow-Origin", "*")
       let $json  := json:xml-to-json($page)
       return
           if ($callback ne "")
           then 
              concat($callback,"(",$json,")")
           else $json
  else ()
};