declare namespace fw = "http://kitwallace.me/fw";

declare function fw:filter($path as xs:string, $type as xs:string, $param as item()*) as xs:boolean {
 (: pass all :)
 true()
};

declare function fw:list($path as xs:string, $type as xs:string, $data as item()? , $param as item()*) {
 (: return a list of the items in the zip file. :)
 <item path="{$path}" type="{$type}"></item>
};

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