(:

To do a bulk replacement on a directory of xq and xqm files using a text file of find/replace strings

e.g.  rename.xq?from=/db/apps/iati-api/lib2/&to=/db/apps/iati-dev/lib&file=/db/apps/iati-api/system/rename.txt
:)

import module namespace wfn = "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";

<result>
{
let $login := xmldb:login("/db/apps/iati-api","admin","perdika")
let $from := request:get-parameter("from",())
let $to := request:get-parameter("to",())
return if ($to=$from) then <div>from and to are the same</div> else
let $file := request:get-parameter("replacements",())
let $r := util:binary-to-string(util:binary-doc($file))
let $strings := tokenize(normalize-space($r)," ")
let $replacements :=
  for $i in (1 to xs:integer(count($strings) div 2 ))
  let $find := normalize-space($strings[$i * 2 - 1] )
  let $replace := normalize-space($strings[$i * 2 ] )
  return 
    <replace find="{$find}" replace="{$replace}"/>
for $file in xmldb:get-child-resources($from)[ends-with(.,"xq") or ends-with(.,"xqm")]
let $text := util:binary-to-string(util:binary-doc(concat($from,$file)))
let $newtext := wfn:replace($text,$replacements)
let $store := xmldb:store($to,$file,$newtext,"application/xquery")
return $store
}
</result>
