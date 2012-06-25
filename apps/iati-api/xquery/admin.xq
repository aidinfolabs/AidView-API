import module namespace iati-b = "http://kitwallace.me/iati-b" at "../lib/iati-b.xqm";
import module namespace iati-p = "http://kitwallace.me/iati-p" at "../lib/iati-p.xqm";
import module namespace wfn =  "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";
import module namespace ui =  "http://kitwallace.me/ui" at "/db/lib/ui.xqm";    
import module namespace log = "http://kitwallace.me/log" at "/db/lib/log.xqm";
import module namespace login = "http://kitwallace.me/login" at "/db/lib/login.xqm";
declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";

let $admin-query := doc(concat($iati-b:system,"model.xml"))/model/entity[@name="admin-query"]
let $query := ui:get-entity($admin-query) 
let $query := login:add-member-to-query($query)
let $logit := log:log-request("iati","admin",$query/membername)
let $login := xmldb:login($iati-b:base,"admin","perdika") 
let $content := iati-p:admin-content($query,"admin.xq") 
return  
 if ($query/format="html")
 then 
  let $s := util:declare-option("exist:serialize",  
   "method=xhtml media-type=text/html omit-xml-declaration=no indent=yes") 
  return
 <html>
   <head>
     <title>IATI eXist Admin</title>
     <link rel="stylesheet" type="text/css" href="../assets/screen-2.css"/>
     <script src="../../../jscript/sorttable.js" type="text/javascript" charset="utf-8"></script>
     <meta name="robots" content="noindex, nofollow"/>
   </head>
   <body>
   <h1><a href="admin.xq">IATI-API Admin</a></h1>
   {$content}
<!--   <a href="http://validator.w3.org/check?uri={encode-for-uri(request:get-url())}?{encode-for-uri(request:get-query-string())}">XHTML validate</a> -->
   </body>
 </html>   
else if ($query/format="xml")
then $content 
else () 