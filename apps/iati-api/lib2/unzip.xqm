module namespace iati-dl = "http://kitwallace.me/iati-dl";

import module namespace iati-b = "http://kitwallace.me/iati-b" at "iati-b.xqm";
import module namespace iati-l = "http://kitwallace.me/iati-l" at "iati-l.xqm";

declare function iati-dl:filter($path as xs:string, $type as xs:string, $param as item()*) as xs:boolean {
 (: pass all :)
 true()
};

declare function iati-dl:list($path as xs:string, $type as xs:string, $data as item()? , $param as item()*) {
 (: return a list of the items in the zip file. :)
 <item path="{$path}" type="{$type}"></item>
};


declare function iati-dl(
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

declare function iati-l:load-xml($source as xs:string, $activitySets as element(activitySets) ,$query) {
let $activity-collection := concat($iati-b:data,$query/corpus,"/activities")
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

let $download := iati-l:download-activities($the-activitySet,$query)
return $source
};
