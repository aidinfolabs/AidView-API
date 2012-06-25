import module namespace iati-b = "http://kitwallace.me/iati-b" at "iati-b.xqm";

declare option exist:serialize "method=xhtml media-type=text/html";

<html>
     <head>
         <title>IATI eXist - documentation</title>
     </head>
     <body>
         <h1><a href="home.html">IATI eXist</a> - documentation</h1>
         <h2>Library Modules</h2>
         <ul>
             {for $module in doc(concat($iati-b:base,"system/module-structure.xml"))/module-list/module
              let $path := 
                if (starts-with($module/@source,'/'))
                then $module/@source/string()
                else concat($iati-b:base,"xquery/",$module/@source)
              return 
                <li>
                    <a href="../../sys/xquery/moduleAnalysis.xq?module={$path}.xqm">{$module/@source/string()}</a>&#160;
                    {$module/string()}
                </li>
              }
         </ul>
     </body>
</html>

