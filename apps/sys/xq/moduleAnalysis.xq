import module namespace wfn = "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";
import module namespace ui= "http://kitwallace.me/ui" at "/db/lib/ui.xqm";

declare namespace svg = "http://www.w3.org/2000/svg";

declare variable $query := 
 <query>
  { ui:get-parameter("module",())}
  { ui:get-parameter("page","html")}
  { ui:get-parameter("function","all")}
  { ui:get-parameter("count",())}
  { ui:get-parameter("config",())}
 </query>;

(: 
declare option exist:serialize "method=xhtml media-type=application/xhtml+xml omit-xml-declaration=no indent=yes 
        doctype-public=-//W3C//DTD&#160;XHTML&#160;1.0&#160;Strict//EN
        doctype-system=http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd";
:)
declare option exist:serialize "method=xhtml media-type=text/html";

declare function local:linkage-graph ($analysis) {
let $graph :=
<graph>
digraph calls {{ 
  size="15,8"; ratio=fill;
  {for $function in $analysis/functions/function   (: [name = $analysis/calls/call/(@from|@to)] :)
   let $lone := empty($analysis/calls/call[@to=$function/name]/@from)
   return
   <node>"{$function/name/string()}" [ {if ($lone) then "color=red " else ()} URL="{local:uri()}&amp;function={$function/name/string()}"];
   </node>
   }
   {
   for $call in $analysis/calls/call
   return 
       <link>"{$call/@from/string()}" -> "{$call/@to/string()}";
       </link>
   }
  }}
</graph>
return 
  <div>
    <h2>Call graph</h2>
       <svg:svg width="1200"  height="1000">
            <svg:g transform="scale(0.8)">
               { ui:dot($graph,"svg") }
            </svg:g>
        </svg:svg>
   </div>
};

declare function local:split-module($text) {
  if (contains($text,"};"))
  then 
    (concat(substring-before($text,"};"),"};"), local:split-module(substring-after($text,"};")))
  else 
    ()

};

declare function local:parse-function($text) { 

  let $comment := normalize-space(substring-before($text,"declare function"))
  let $function := concat("declare function",substring-after($text,"declare function"))

  let $name := normalize-space(wfn:substring-between($function,"declare function","("))  
  let $prefix := substring-before($name,":")
  let $localName := substring-after($name,":")
  let $signature  := substring-before($function,"{")
  let $parameters := substring-after($signature,"(")
  let $parameters := replace($parameters, "\s+"," ")
  let $parameters := 
        if (contains($parameters,") as"))
        then (substring-before($parameters,") as"),substring-after($parameters,") as"))
        else (substring($parameters,1,string-length($parameters) - 2),"item()*")
  let $returnType := normalize-space($parameters[2])
  let $parameters := tokenize($parameters[1],",")
  let $body := substring-after($text,"{")
  return
  element function {
      element name {$name},
      element prefix {$prefix},
      element localName {$localName},
      element returnType {$returnType},
      if (exists($parameters) )
      then element parameters {
      for $parameter in $parameters 
      let $parameter := normalize-space($parameter)
      let $nametype := if (contains($parameter," as "))
                   then (substring-before($parameter," as "), substring-after($parameter," as "))
                   else ($parameter,"item()*")
      return element parameter {
            element name {$nametype[1]},
            element type {$nametype[2]}
          }
      }
      else (),
      if ($comment ne "") then element comment { $comment } else (),
      element signature {$signature},
      element body { $body}
   }
};

declare function local:functions-calls($functions) {
  <calls>
    {for $function in $functions/function
     let $pattern := concat($function/name,"(")
     for $call in distinct-values(
        for $call-function in $functions/function
        where contains($call-function/body,$pattern)
        return $call-function/name)
     return 
       <call from="{$call}" to="{$function/name}"/>
     }
  </calls>
};

declare function local:uri() {
  if ($query/module)
  then concat("?module=",$query/module)
  else concat("?config=",$query/config)
};

declare function local:analyse($config) {
let $functions :=
  <functions>
    {
for $modulefile in $config/module
let $text := util:binary-to-string(util:binary-doc($modulefile))
let $functiontext := concat("declare function ",substring-after($text,"declare function"))

let $module-parts := local:split-module($functiontext)
for $function in $module-parts[contains(.,"declare function")]
return 
    local:parse-function($function)
    }
  </functions>
        
let $calls := local:functions-calls($functions)
let $functions :=
  <functions> {
     for $function in $functions/function
     return 
        <function>
           {$function/*}
           {let $calls :=
             for $call in $calls/call[@from = $function/name]
             return
               <call uri="{local:uri()}&amp;function=">{$call/@to/string()}</call>
            return 
              if ($calls)
              then element calls {$calls}
              else ()
           }
        </function>
    }
  </functions>
return
 <analysis>
   {$config/*}
   {$functions}
   {$calls}
 </analysis>
};

declare function local:all-functions($analysis) {
  <div class="level1">
    <table border="1" class="sortable"> 
     <tr>
       <th>LocalName</th>
       <th># Parameters </th>
       <th>Parameters</th>
       <th>Calls</th>
     </tr>
   { for $function in $analysis/functions/function
     let $count := count($function//parameter)
     order by $function/name, $count
     return
      <tr>
         <td><a href="{local:uri()}&amp;function={$function/name}&amp;count={$count}">{$function/name/string()}</a></td>
         <td>{$count}</td>
         <td>{string-join($function//parameter/name,", ")}</td>
         <td>{for $call in $analysis/calls/call[@from=$function/name]/@to
              return <span class="link"><a href="{local:uri()}&amp;function={$call}">{$call/string()}</a></span>
              }
         </td>
     </tr>
   }     
   </table>
 </div>
};

declare function local:function ($analysis, $fname, $count) {

    let $functions := $analysis/functions/function[name=$fname]
    let $function := if ($count) then $functions[count(.//parameter)=$count] else $functions[1]
    let $body := $function/body
    let $body := replace($body,"xmldb:login(.*,.*,.*)","xmldb:login(*collection*,*username*,*password*)")
    return 
    if (exists($function))
    then 
    <div class="level1">
      <h2>{$function/name}</h2>
      <table>
        {ui:rows-as-table("parameters",
         for $parameter in $function//parameter
         return <tr><th>{$parameter/name/string()}</th><td>{$parameter/type/string()}</td></tr>
         )
       }
       {ui:row("Return",$function/returnType/string())}
       {ui:row("Calls",  
         for $call in $analysis/calls/call[@from=$function/name]/@to
         return 
            <a href="{local:uri()}&amp;function={$call}">{$call/string()}</a>
         )
        }
        {ui:row("Called by",
         for $call in $analysis/calls/call[@to=$function/name]/@from
         return 
          <a href="{local:uri()}&amp;function={$call}">{$call/string()}</a>
         )
        }
        <tr><th valign="top">Comment</th><td><a href="javascript:showElement('comment')">Show</a><a href="javascript:hideElement('comment')">Hide</a><pre class="show" id="comment">{$function/comment/string()}</pre></td></tr>     
        <tr><th valign="top">Body </th><td><a href="javascript:showElement('body')">Show</a><a href="javascript:hideElement('body')">Hide</a><pre class="show" id="body">{normalize-space($function/signature)}{{{$body}</pre></td></tr>     
      </table>
   </div>
    else ()
};

declare function local:all-calls ($analysis) {

 <div class="leve1">
     <h2>Function calls</h2>
     <ul>
    {for $call in $analysis/calls/call
     return
       <li><a href="?{local:uri()}&amp;function={$call/@from}">{$call/@from/string()}</a> calls 
           <a href="?{local:uri()}&amp;function={$call/@to}">{$call/@to/string()}</a>
       </li>
    }
   </ul> 
  </div>
};

let $config := 
    if ($query/config)
    then doc($query/config)/config
    else <config><name>{tokenize($query/module,"/")[last()]}</name><module>{$query/module}</module></config>
    
let $analysis := local:analyse($config)
return

<html xmlns="http://www.w3.org/1999/xhtml" xmlns:svg="http://www.w3.org/2000/svg">
  <head>
    <title>Analysis of {$analysis/*:name/string()}</title>
      <style type="text/css"> 
       td,th {{font-size: 95%}}
       .level1 {{background-color: #efe;}}
       .level2 {{background-color: #ded;}}
       .level3 {{background-color: #cdc;}}
        th {{text-align: right; padding:5px; font-weight:bold;}}
        a {{padding:3px;}}
       .hide {{display:none}}
       </style>
       <script type="text/javascript" src="http://www.kryogenix.org/code/browser/sorttable/sorttable.js"/>
       <script type="text/javascript">
       <![CDATA[
       function hideElement(i) {
var e = document.getElementById(i);
if (e) {
e.style.display = 'none';
}
}

function showElement(i) {
var e = document.getElementById(i);
if (e) {
e.style.display = 'block';
}
} ]]>
</script>
  </head>
  <body>
   <h1>Analysis of {$analysis/*:name/string()}</h1>
   <div>
       <a href="{local:uri()}&amp;function=all">Functions</a>
       <a href="{local:uri()}&amp;page=linkage">Call Graph</a>
       {for $test in $analysis/*:test
        return
        <a href="runTests.xq?testfile={$test/@path}">{$test/string()}</a>
       }
   </div>
{ 
if ($query/*:page="linkage") 
then local:linkage-graph($analysis)
else
if ($query/*:function="all")
then 
  local:all-functions($analysis)
else if (exists($query/*:function))
then 
  local:function($analysis,$query/*:function ,$query/*:count)
else if ($query/page="calls")
then 
  local:all-calls($analysis)
else ()
}

  </body>
</html>