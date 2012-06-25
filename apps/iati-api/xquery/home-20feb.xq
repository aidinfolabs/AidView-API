import module namespace iati-b = "http://kitwallace.me/iati-b" at "../lib/iati-b.xqm";
import module namespace iati-h = "http://kitwallace.me/iati-h" at "../lib/iati-h.xqm";
import module namespace wfn =  "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";
import module namespace ui =  "http://kitwallace.me/ui" at "/db/lib/ui.xqm";    
import module namespace log = "http://kitwallace.me/log" at "/db/lib/log.xqm";

declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";
declare variable $local:cache := doc("/db/apps/iati-api/cache/home2.xml")/cache;

declare option exist:serialize  "method=xhtml media-type=text/html omit-xml-declaration=no indent=yes";
let $message := "under repair"
return if (true()) then $message else 

let $clear := if (request:get-parameter("refresh","") = "all") then update delete $local:cache/node() else ()

let $refresh := request:get-parameter("refresh",()) = "page"
let $home-query := doc(concat($iati-b:system,"model.xml"))/model/entity[@name="home-query"]
let $query := ui:get-entity($home-query) 
let $qs := replace (request:get-query-string(),"&amp;refresh=.","")
let $key := if (exists($qs)) then util:hash($qs,"md5") else "home" 

let $cached-page := if ($refresh) then () else $local:cache/page[@key=$key]
let $page :=
 if (exists($cached-page))
 then $cached-page/node()
 else iati-h:home-content($query,"home.xq")   
let $cacheit := 
   if ($page/@class="cache" and empty($cached-page))
   then  
     update insert 
     element page {
         attribute key {$key},
         $page
     }
     into $local:cache
   else if ($refresh and exists($cached-page))
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
     <title>AidInfo IATI DataStore </title>
     <link rel="stylesheet" type="text/css" href="../assets/screen-2.css"/>
     <script src="../../../jscript/sorttable.js" type="text/javascript" charset="utf-8"></script>
     <meta name="robots" content="noindex, nofollow"/>
   </head>
   <body>
   <h1><a href="?">AidInfo IATI DataStore</a></h1>
   {$page}
<!--   <a href="http://validator.w3.org/check?uri={encode-for-uri(request:get-url())}?{encode-for-uri(request:get-query-string())}">XHTML validate</a> -->
   </body>
 </html>
