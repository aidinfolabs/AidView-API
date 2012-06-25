declare option exist:serialize "method=xhtml media-type=text/html";
declare variable $local:db := "/db/temp/";
declare variable $local:url := "/exist/rest/db/temp/";

declare function local:zip($resources as xs:string*, $filename) {
let $uris := 
for $resource in $resources
return xs:anyURI($resource)
let $filename := concat($filename,".zip")
let $zip := compression:zip($uris,true())
let $login := xmldb:login($local:db,"admin","perdika")
let $store := xmldb:store($local:db,$filename,$zip)
return  concat($local:url,$filename)
};

declare function local:list-resources($resources,$config) {
      <table border ="1" class="sortable">
            <tr><th width="30%">Resource</th><th>Export?</th><th>Description</th><th>Links</th></tr>
            {for $resource in $resources
             let $path := 
               if (starts-with($resource/@path,"/")) 
               then $resource/@path/string()
               else concat($config/base,"/",$resource/@path)
             let $suffix := substring-after(tokenize($path,"/")[last()],".")
             return 
               <tr>
                   <td>
                      {if ($suffix = ("xml","xsl","css","xconf","js"))
                       then <a href="/exist/rest/{$path}">{$path}</a>   
                       else if ($suffix="xqm")
                       then <a href="moduleAnalysis.xq?module={$path}">{$path}</a> 
                       else $path
                      }
                   </td>
                   <td>{if (empty($resource/@ignore)) then "*" else () }</td>
                   <td>{$resource/description/string()}</td>
                   <td>{for $link in $resource/link
                        return <a href="{$config/url}&amp;path={$link}">{$link/string()}</a>
                        }
                    </td>
               </tr>
            }
         </table>
};

let $resourceFile := request:get-parameter("resourceFile",())
return if (not(starts-with($resourceFile,"/db"))) then () else
let $mode := request:get-parameter("mode","view")
let $path := request:get-parameter("path",())
let $basepath := request:get-parameter("base",())
let $resources := doc($resourceFile)/resources
let $base := string(($resources/@base,$basepath)[1])
let $config := 
element config {
  element base {$base},
  element url  {concat ("?resourceFile=",$resourceFile,"&amp;base=",$basepath)}
}

return
  if ($mode="view" and empty($path))
  then 
    <div>
      <h2>{$resources/@name/string()}</h2>
         <div><a href="{$config/url}&amp;mode=zip">Zip it</a>
         </div>
            {local:list-resources($resources/resource,$config)}
    </div>
  else if ($mode="view" and exists($path))
  then 
    <div>
      <h2>{$resources/@name/string()} : {$path}</h2>
         <div><a href="{$config/url}&amp;mode=zip">Zip it</a>
         <a href="{$config/url}&amp;mode=view">View all</a>
         </div>
         {local:list-resources($resources/resource[@path=$path],$config)}
    </div>
  else if ($mode="zip")
  then 
    let $zipfilename := concat($resources/@name,"-backup")
    let $paths := 
      for $path in $resources/resource[empty(@ignore)]/@path
      return 
        if (starts-with($path,"/")) 
        then $path
        else concat($base,"/",$path)

    let $zip := local:zip($paths , $zipfilename)
    return
      <div> 
         <h2>{$resources/@name/string()} </h2>
         <div>
         <a href="{$config/url}&amp;mode=view">View</a>
         </div>
           <div>
           zipped to  <a href="{$zip}">{$zip}</a> </div>
      </div>
  else ()