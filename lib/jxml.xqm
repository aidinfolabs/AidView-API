(:
  a hack conversion from json to xml
  presumption is that  [  ] { } only used as json syntax not as characters in quoted strings 
  parsing of comma-separated text supports embedded , and : , relying on "\s*: as a separator
  if the hint <rough is present in the flags, arrays will be split on comma - this is needed because the 
  recursive algorithm for text parsing causes stack overflow after 99 iterations.
  embedded HTML is not supported
  root is div 
  un named arrays or blocks are enclosed in divs
  element names are expected to be valid XML names
  
  this works with the current (May 2012) CKAN package data
  
  it should be replaced when a module in eXist supporting this transformation becomes available
  
:)

module namespace jxml = "http://kitwallace.me/jxml";
import module namespace hc= "http://expath.org/ns/http-client";

declare variable $jxml:amp :=  codepoints-to-string(38);  

declare function jxml:substring-between($s,$start,$end) {
   let $substring := 
         if (empty($start)) then substring-before($s,$end)
         else if (empty($end)) then substring-after($s,$start)
         else 
           let $rest := substring-after($s,$start)
           return 
              if (contains($rest,$end))
              then substring-before($rest,$end)
              else $rest
  return normalize-space($substring)
};

declare function jxml:parse-csv-rough($s) {
  for  $sub in tokenize($s,",")
  return 
    element item
       {jxml:substring-between(normalize-space($sub),'"','"')}

};

declare function jxml:parse-csv($s) {
 let $s := normalize-space($s)
 return
 if ($s eq "") then ()
 else
 if (contains($s,'"') or contains($s,','))
 then
  if (starts-with($s,'"'))
  then let $ss := jxml:substring-between($s,'"','"')
           let $rem := substring-after(substring-after($s,$ss),",")
           return (element item {$ss}, jxml:parse-csv($rem))
  else  
          let $ss := substring-before($s,",")
          let $rem := substring-after($s,",")
          return (element item {$ss}, jxml:parse-csv($rem))
  else element item {$s}
};

declare function jxml:parse-text($item) {
  let $parts := tokenize($item,'"\s*:')
  let $subs  := 
   for $part in $parts 
   where normalize-space($part) ne ""
   return 
     <p>{jxml:parse-csv($part)}</p>
  return 
  for $sub at $i in $subs
  let $name := if ($i = 1) then $sub/item[1]/string() else $sub/item[2]/string()
  let $i1 := $i + 1
  let $value := normalize-space($subs[$i1]/item[1]/string())
  return
    if (exists($name))
    then
     <token> 
        <name>{translate($name,":","-") }</name>
        {if ($value ne "") then 
           <value>{$value}</value>
         else ()
        }
     </token>
    else ()
};


declare function jxml:parse-json($items , $flags ) {
  for $item at $i in $items
  return    
      typeswitch($item) 
     
  case text() return
        let $text := normalize-space($item)
        let $text := if (starts-with($text,",")) then substring($text,2) else $text
        return 
        if ($text="") then ()
         else
         if ($item/.. instance of element(array))
         then  if (exists($flags/rough))
         then jxml:parse-csv-rough($text)
         else jxml:parse-csv($text)
         else 
            let $parse :=  jxml:parse-text($text)
            for $token in $parse
            return 
              if (exists($token/value))
              then element {$token/name}  {$token/value/string()}
              else element div-name {$token/name/string()}
  
  case element(div) return
      element div {
          jxml:parse-json($item/node(), $flags)
      }
  case element(array) return
      element div {
          jxml:parse-json($item/node() , $flags)
      }
      
  default return $item
};

declare function jxml:group($items) {
  for $item in $items 
  return
     typeswitch ($item) 
      case element(div-name)  return
          element {$item} { 
             jxml:group($item/following-sibling::div[1]/*)
             }
      case element(div) return
          let $name := $item/preceding-sibling::*[1]
          return 
            if ($name instance of element(div-name))
            then ()  (: drop the div because its been absorbed as the preceding child :)
            else 
              element div {
                jxml:group($item/*)
             }
       default return
         if (exists($item/*))
         then 
             element {name($item)}
                {jxml:group($item/*)}
         else 
           $item
};

declare function jxml:convert ($json, $flags) {

  let $text := replace ($json,$jxml:amp,"&amp;amp;")
  let $text := replace($text,"&lt;","xxx")
  let $text := replace($text,"\{","<div>")
  let $text := replace($text,"\}","</div>")
  let $text := replace($text,"\]","</array>")
  let $text := replace($text,"\[","<array>")
  
  let $xml := util:parse(concat("<div>",$text,"</div>"))

  let $parse := jxml:parse-json($xml/div, $flags) 
  return 
      jxml:group($parse)
};

(: should have some error-reporting here :)

declare function jxml:convert-url ($url, $flags) {
let $request :=
   element hc:request {attribute method {"GET"}, attribute href {$url}, attribute timeout {"3"} }
let $result := hc:send-request($request)
let $meta := $result[1]
let $data := $result[2]
return 
  if (empty($meta) or empty($data))
  then ()
  else 
   if ($meta/hc:body/@media-type = "application/json")
   then let $json := util:binary-to-string($data)   
        return 
            if (exists($json))
            then jxml:convert($json, $flags)
            else ()
   else ()
};

declare function jxml:convert-url ($url) {
 jxml:convert-url($url,())
};

declare function jxml:convert($json) {
  jxml:convert($json,())
};