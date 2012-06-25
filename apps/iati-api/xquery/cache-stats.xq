import module namespace stats = "http://tools.aidinfolabs.org/api/stats" at "../lib/stats.xqm";
import module namespace base = "http://kitwallace.me/iati-b" at "iati-b.xqm";

let $query :=
  <query> 
     <corpus>{request:get-parameter("corpus","fullB")}</corpus>
  </query>
let $stats := stats:all-statistics($query)
let $login := xmldb:login($base:base,"admin","perdika")
let $store := xmldb:store(concat($base:base,"cache/",$query/corpus),"corpus-statistics.xml",$stats)
return $store

