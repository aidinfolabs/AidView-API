import module namespace config = "http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";  
import module namespace load = "http://tools.aidinfolabs.org/api/load" at "../lib/load.xqm";  

declare variable $local:corpus external;

let $login := config:login()
return load:ckan-activitySets(<context><corpus>{$local:corpus}</corpus><ckanall/></context>)
