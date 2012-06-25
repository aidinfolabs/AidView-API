(:
  save the zip resources file to a directory on the web so that the file can be download eg using wget
  files are not timestamped so only one backup per resourcefile name is stored
:)

declare option exist:serialize "method=xhtml media-type=text/html";
declare variable $local:backups := "/var/www/backups/";
declare variable $local:hostpath := "http://109.104.101.243/backups/";   (: host specific :)

declare function local:zip($resources as xs:string*) {
let $uris := 
for $resource in $resources
return xs:anyURI($resource)

return compression:zip($uris,true())
};

declare function local:cache-fs($resources,$config) {
 for $resource in $resources[@fspath]
 let $path := 
               if (starts-with($resource/@path,"/")) 
               then $resource/@path/string()
               else concat($config/base,"/",$resource/@path)
 let $filename := tokenize($path,"/")[last()]
 let $collection := substring-before($path,$filename)
 let $suffix := substring-after($filename,".")
 
 let $file:=
    if ($suffix = ("xml","xslt"))
    then 
        file:read($resource/@fspath)
    else 
        file:read-binary($resource/@fspath)
 return xmldb:store($collection,$filename,$file)

};

declare function local:list-resources($resources,$config) {
      <table border ="1" class="sortable">
            <tr><th width="30%">Resource</th><th>Export?</th><th>Filestore?</th><th>Description</th><th>Links</th></tr>
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
                       else $path
                      }
                   </td>
                   <td>{if (empty($resource/@ignore)) then "yes" else () }</td>
                   <td>{if ($resource/@fspath) then "yes" else () } </td>
                   <td>{$resource/description/string()} {if ($resource/@fspath) then concat (" [ ", $resource/@fspath, "]") else () } </td>
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
      <h2>{$resources/@name/string()} - {$resourceFile}</h2>
         <div><a href="{$config/url}&amp;mode=zip">Zip it</a>
         </div>
            {local:cache-fs($resources,$config)}
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
    let $zipfilename := concat($resources/@name,"-backup.zip")
    let $paths := 
      for $path in $resources/resource[empty(@ignore)]/@path
      return 
        if (starts-with($path,"/")) 
        then $path
        else concat($base,"/",$path)

    let $zip := local:zip($paths)
    let $login := xmldb:login("/db/apps","admin","perdika")
    let $store := file:serialize-binary($zip,<name>{concat($local:backups,$zipfilename)}</name>)
    return
      if ($store)
      then 
      <div> 
         <h2>{$resources/@name/string()} - {$resourceFile}</h2>
         <div>
         <a href="{$config/url}&amp;mode=view">View</a>
         <a href="{$local:hostpath}{$zipfilename}">Download zip</a>
         </div>
      </div>
    else 
    <div>
        <h2>{$resources/@name/string()} - {$resourceFile}</h2>
        <div> zip or store failed</div>
    </div>
  else ()