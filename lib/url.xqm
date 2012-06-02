module namespace url = "http://kitwallace.me/url";

import module namespace wfn = "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";

declare function url:parse-template($path) as element(query) {
   let $steps := tokenize($path,"/")
   return
     element query {
       for $step at $i in $steps
       let $next := $steps[$i + 1] 
       return
         if (contains($step,"{"))
         then () (: will have been processed in preceding step :)
         else if (exists($next) and contains($next,"{"))
         then 
             element {$step} {wfn:substring-between($next,"{","}")}
         else if (empty($next))
         then element {$step} {"*"}
         else element {$step} {}
     }
};

declare function url:parse-path($steps) {
     if (count($steps) = 0)
     then ()
     else if (count($steps) = 1)
     then element {$steps[1]} {()}
     else  (element {$steps[1]} {$steps[2]}, url:parse-path(subsequence($steps,3)))   
};

declare function url:path-to-sig($steps) {
     if (count($steps) = 0)
     then ()
     else if (count($steps) = 1)
     then $steps[1]
     else  ($steps[1],"*",url:path-to-sig(subsequence($steps,3)))   
};

declare function url:get-context() as element(context) {  
   let $path := request:get-parameter("_path",())
   let $path := if (ends-with($path,"/")) then substring($path, 1, string-length($path) - 1) else $path 
   let $steps := tokenize($path,"/")
   let $signature := string-join(url:path-to-sig($steps),"/")
   return
     element context {
       for $param in request:get-parameter-names()
       let $value := request:get-parameter($param,())
       return element {$param} {attribute qs {"true"} ,$value},
       element _nparam {count(request:get-parameter-names())},
       element _signature {$signature},
       for $step in $steps return element _step {$step},
       url:parse-path($steps)
     }
};

declare function url:create-dispatcher ($function-name,$functions) {
concat(
"declare function ",$function-name,"($signature,$context) {&#10;",
 string-join(
 for $function in $functions
 return
  concat("if ($signature eq '",$function/@signature,"') then ",$function/text())
 , " &#10; else "
 )
 ,"&#10; else ()"
 ,"&#10;};"
)
};

declare function url:path-menu($path, $options, $map) {
let $steps := subsequence(tokenize($path,"/"),2)  (: first char is / :)
return
  (
   wfn:node-join(
    for $step at $i in $steps
    let $label := if ($i=1) then "Home" else if ($i mod 2 = 0) then replace(($map/term[@name = $step]/string(), $step)[1],"_","/") else $step
    let $step-path := concat("/",string-join(subsequence($steps,1,$i),"/"))
    return
       if ($i eq count($steps) )
       then if ($step ne "") then element span {$label} else ()
       else element a {attribute href {$step-path}, $label }

    ," > ")
    ,
    if (exists($options))
    then 
    (" > ",
    wfn:node-join(
    for $option in $options
    let $label := ($map/term[@name = $option]/string(), $option)[1]
    return 
      element a {attribute href {concat($path,"/",$option)}, $label }
    , " | ")
    )
    else ()
   )
};