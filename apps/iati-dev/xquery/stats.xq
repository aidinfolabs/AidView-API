import module namespace stats = "http://tools.aidinfolabs.org/api/stats" at "../lib/stats.xqm";
import module namespace config = "http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";

let $query :=
  <query> 
     <corpus>{request:get-parameter("corpus","fullB")}</corpus>
  </query>
let $stats := stats:all-statistics($query)
let $login := config:login()
let $store := xmldb:store(concat($config:base,"olap"),concat($query/corpus,"-stats.xml"),$stats)
return $store

