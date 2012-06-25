import module namespace config = "http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";

declare option exist:serialize "method=xhtml media-type=text/html";
let $resources := doc("/db/apps/iati-dev/system/resources.xml")/resources
return
<html>
     <head>
         <title>IATI eXist - documentation</title>
     </head>
     <body>
         <h1><a href="home.html">IATI eXist</a> - documentation</h1>
         <h2>Library Modules</h2>
         <ul>
             {for $module in $resources/resource[ends-with(@path,"xqm")]
              let $fullpath := if (starts-with($module/@path,"/")) then $module/@path/string() else concat($resources/@base,"/",$module/@path)
              return 
                <li>
                    <a href="../../sys/xquery/moduleAnalysis.xq?module={$fullpath}.xqm">{$fullpath}</a>&#160;
                    {$module/description/string()}
                </li>
              }
         </ul>
     </body>
</html>

