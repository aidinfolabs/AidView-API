import module namespace iati-b = "http://kitwallace.me/iati-b" at "../lib/iati-b.xqm";
import module namespace iati-vp = "http://kitwallace.me/iati-vp" at "../lib/iati-vp.xqm";
import module namespace wfn =  "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";
import module namespace ui =  "http://kitwallace.me/ui" at "/db/lib/ui.xqm";
import module namespace log = "http://kitwallace.me/log" at "/db/lib/log.xqm";

declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";

let $validate-query := doc(concat($iati-b:system,"model.xml"))/model/entity[@name="validate-query"]
let $query := ui:get-entity($validate-query)

let $logit := log:log-request("iati","validate",())
let $login := xmldb:login($iati-b:base,"admin","perdika")
let $content := iati-vp:validate-content($query,"validate.xq")
return 
if ($query/format = "html")
then 
  let $s := util:declare-option("exist:serialize","method=xhtml media-type=text/html")
  return 
 <html>
   <head>
     <title>IATI eXist Validate</title>
     <link rel="stylesheet" type="text/css" href="../assets/screen-2.css"/>
     <script src="../../../jscript/sorttable.js" type="text/javascript" charset="utf-8"></script>
     <meta name="robots" content="noindex, nofollow"/>

   </head>
   <body>
   <h1>IATI-API Validate</h1>
   
   {$content}

   </body>
 </html>
else 
  $content