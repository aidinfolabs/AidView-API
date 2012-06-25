module namespace downloadzip = "http://kitwallace.me/downloadzip";

import module namespace config = "http://kitwallace.me/config" at "config.xqm";
import module namespace load = "http://kitwallace.me/load" at "load.xqm";

declare function downloadzip:filter($path as xs:string, $type as xs:string, $param as item()*) as xs:boolean {
 (: pass all :)
 true()
};

declare function downloadzip:list($path as xs:string, $type as xs:string, $data as item()? , $param as item()*) {
 (: return a list of the items in the zip file. :)
 <item path="{$path}" type="{$type}"></item>
};


declare function downloadzip(
<result>
{
let $url := request:get-parameter("url",())
let $doc := httpclient:get(xs:anyURI($url),false(),())
let $headers := $doc/httpclient:headers
let $type := $headers/httpclient:header[@name="Content-Type"]/@value
return 
  if (contains($type,"application/zip") or contains($type,"application/x-zip-compressed") )
  then let $zip := $doc/httpclient:body
       let $filter := util:function(QName("http://kitwallace.me/fw","fw:filter"),3)
       let $list := util:function(QName("http://kitwallace.me/fw","fw:list"),4)
       let $content := compression:unzip($zip,$filter,(),$list,())
       return $content
  else 
    $headers
}
</result>

declare function load:load-xml($source as xs:string, $activitySets as element(activitySets) ,$query) {
let $activity-collection := concat($config:data,$query/corpus,"/activities")
let $activitySet := $activitySets/activitySet[download_url = $source]
let $new-activitySet := 
  <activitySet>
        <download_url>{$source}</download_url>
        <host>{if ($query/host) then $query/host/string() else substring-before(substring-after($source,"//"),"/")}</host>
        <cache-modified>{current-dateTime()}</cache-modified>
  </activitySet>
let $activitySetUpdate := 
       if  (exists($activitySet))
       then update replace $activitySet with $new-activitySet
       else update insert $new-activitySet into $activitySets

let $the-activitySet := $activitySets/activitySet[download_url = $source]

let $download := load:download-activities($the-activitySet,$query)
return $source
};
