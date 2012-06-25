import module namespace iati-b = "http://kitwallace.me/iati-b" at "../lib/iati-b.xqm";
import module namespace iati-h = "http://kitwallace.me/iati-h" at "../lib/iati-h-4.xqm";
import module namespace wfn =  "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";
import module namespace ui =  "http://kitwallace.me/ui" at "/db/lib/ui.xqm";    
import module namespace log = "http://kitwallace.me/log" at "/db/lib/log.xqm";

declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";
declare variable $local:cache := doc("/db/apps/iati-api/cache/home.xml")/cache;

declare option exist:serialize  "method=xhtml media-type=text/html omit-xml-declaration=no indent=yes";

let $clear := if (request:get-parameter("flush","") = "yes") then update delete $local:cache/node() else ()

let $home-query := doc(concat($iati-b:system,"model.xml"))/model/entity[@name="home-query"]
let $query := ui:get-entity($home-query) 
let $qs := request:get-query-string()
let $key := if (exists($qs)) then util:hash($qs,"md5") else "home" 

let $cached-page := $local:cache/page[@key=$key]
let $page :=
 if (exists($cached-page) and not (request:get-parameter("refresh",()="yes")))
 then $cached-page/node()
 else iati-h:home-content($query,"home.xq")   
let $cacheit := 
   if ($page/@class=("cache","refresh") and empty($cached-page))
   then  
     update insert 
     element page {
         attribute key {$key},
         $page
     }
     into $local:cache
   else if ($page/@class="refresh" and exists($cached-page))
   then  
     update 
     replace $cached-page with
     element page {
         attribute key {$key},
         $page
     }

   else ()
let $logit := log:log-request("iati","home-4","")
let $s := util:declare-option("exist:serialize",
   "method=xhtml media-type=text/html omit-xml-declaration=no indent=yes")        
return
 <html>
   <head>
     <title>IATI-API - Home</title>
     <link rel="stylesheet" type="text/css" href="../assets/screen-2.css"/>
     <script src="../../../jscript/sorttable.js" type="text/javascript" charset="utf-8"></script>
     <meta name="robots" content="noindex, nofollow"/>
   </head>
   <body>
   <h1><a href="?">IATI-API - Home</a></h1>
   {$page}
<!--   <a href="http://validator.w3.org/check?uri={encode-for-uri(request:get-url())}?{encode-for-uri(request:get-query-string())}">XHTML validate</a> -->
   </body>
 </html>
