import module namespace jxml = "http://kitwallace.me/jxml" at "/db/lib/jxml.xqm";
import module namespace hc= "http://expath.org/ns/http-client";

let $url := "http://www.cafod.org.uk/extra/data/iati/IATIFile_Afghanistan.xml"

let $request :=
   element hc:request {attribute method {"GET"}, attribute href {$url}, attribute timeout {"5"} }

let $result := hc:send-request($request)
let $meta := $result[1]
let $data := $result[2]
return 
   if ($meta/hc:body/@media-type = "application/xml")
   then $result[2]
   else ()
