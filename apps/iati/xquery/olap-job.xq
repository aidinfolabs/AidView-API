import module namespace config = "http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";  
import module namespace olap = "http://tools.aidinfolabs.org/api/olap" at "../lib/olap.xqm";  

declare variable $local:corpus external;

let $login := config:login()
return olap:compute-facets(<context><corpus>{$local:corpus}</corpus></context>)
