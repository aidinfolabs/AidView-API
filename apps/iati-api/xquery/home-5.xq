import module namespace iati-b = "http://kitwallace.me/iati-b" at "../lib/iati-b.xqm";
import module namespace iati-h = "http://kitwallace.me/iati-h" at "../lib/iati-h-5.xqm";
import module namespace wfn =  "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";
import module namespace ui =  "http://kitwallace.me/ui" at "/db/lib/ui.xqm";    
import module namespace log = "http://kitwallace.me/log" at "/db/lib/log.xqm";

declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";
declare variable $local:cache := doc("/db/apps/iati-api/cache/home.xml")/cache;

declare option exist:serialize  "method=xhtml media-type=text/html omit-xml-declaration=no indent=yes";

let $clear := if (request:get-parameter("flush","") = "yes") then update delete $local:cache/node() else ()

let $home-query := doc(concat($iati-b:system,"model.xml"))/model/entity[@name="home-query"]
let $query := ui:get-entity($home-query) 
let $page :=iati-h:home-content($query,"home.xq")   
let $logit := log:log-request("iati","home-5","")
return
 <html>
   <head> 
     <title>IATI-API - Home 5</title>
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
