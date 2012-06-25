module namespace zipapp ="http://kitwallace.me/zipapp";

declare function zipapp:zip($resources as xs:string*, $filename) {
let $uris := 
for $resource in $resources
return xs:anyURI($resource)
let $filename := concat($filename,".zip")
let $zip := compression:zip($uris,true())
let $login := xmldb:login("/db/export","admin","perdika")
let $store := xmldb:store("/db/export",$filename,$zip)
return  concat("/exist/rest/db/export/",$filename)
};

