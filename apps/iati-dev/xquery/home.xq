import module namespace config = "http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";
import module namespace home-ui = "http://tools.aidinfolabs.org/api/home-ui" at "../lib/home-ui.xqm";
import module namespace wfn =  "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";
import module namespace ui =  "http://kitwallace.me/ui" at "/db/lib/ui.xqm";    
import module namespace log = "http://kitwallace.me/log" at "/db/lib/log.xqm";

declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";

declare option exist:serialize  "method=xhtml media-type=text/html omit-xml-declaration=no indent=yes";
let $home-query := doc(concat($config:system,"model.xml"))/model/entity[@name="home-query"]
let $query := ui:get-entity($home-query) 
let $page := home-ui:content($query,"home.xq")   
let $logit := log:log-request("iati","home-4","")
let $s := util:declare-option("exist:serialize",
   "method=xhtml media-type=text/html omit-xml-declaration=no indent=yes")        
return
 <html>
   <head>
     <title>AidInfo IATI DataStore </title>
     <link rel="stylesheet" type="text/css" href="../assets/screen-2.css"/>
     <script src="../jscript/sorttable.js" type="text/javascript" charset="utf-8"></script>
     <meta name="robots" content="noindex, nofollow"/>
   </head>
   <body>
   <h1><a href="?">AidInfo IATI DataStore</a></h1>
   {$page}
<!--   <a href="http://validator.w3.org/check?uri={encode-for-uri(request:get-url())}?{encode-for-uri(request:get-query-string())}">XHTML validate</a> -->
   </body>
 </html>
