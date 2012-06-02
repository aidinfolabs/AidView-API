module namespace wfn= "http://kitwallace.me/wfn";
declare variable $wfn:wordchars := 
  element wordchars {
    element replace {attribute find {codepoints-to-string((226,128,147))}, attribute replace {"&#8211;"}, attribute name {"en dash"}}, 
    element replace {attribute find {codepoints-to-string((226,128,148))}, attribute replace {"&#8212;"}, attribute name {"em dash"}}, 
    element replace {attribute find {codepoints-to-string((226,128,152))}, attribute replace {"&#8216;"}, attribute name {"Single left quote"}}, 
    element replace {attribute find {codepoints-to-string((226,128,153))}, attribute replace {"&#8217;"}, attribute name {"Single right quote"}},
    element replace {attribute find {codepoints-to-string((226,128,154))}, attribute replace {"&#8218;"}, attribute name {"Single low-9 left quote"}}, 
    element replace {attribute find {codepoints-to-string((226,128,155))}, attribute replace {"&#8219;"}, attribute name {"Single high-reversed-9 quote"}},
    element replace {attribute find {codepoints-to-string((226,128,156))}, attribute replace {"&#8220;"}, attribute name {"Double right quote"}},
    element replace {attribute find {codepoints-to-string((226,128,157))}, attribute replace {"&#8221;"}, attribute name {"Double right quote"}},
    element replace {attribute find {codepoints-to-string((226,128,158))}, attribute replace {"&#8222;"}, attribute name {"Double low-9 quote"}},
    element replace {attribute find {codepoints-to-string((226,128,159))}, attribute replace {"&#8223;"}, attribute name {"Double high reversed-9 quote"}},
    element replace {attribute find {codepoints-to-string((226,128,172))}, attribute replace {"&#8230;"}, attribute name {"ellipsis"}}
 };
  
declare function wfn:clean-text($text) {
  wfn:replace($text,$wfn:wordchars/*)
};

declare function wfn:average($nums as xs:decimal*) as xs:decimal? {
  if (exists($nums))
  then sum($nums) div count($nums)
  else ()
};

declare function wfn:value-in-ks($val as xs:double) as element(span) {
   let $aval := math:abs($val)  (: this needs a sig putting back else its unsigned :)
   let $scaled-value :=

      if ($aval > 1.0E9) then concat(string(round-half-to-even($val div 1.0E9,3)),"b")
      else if ($aval > 1.0E6) then concat(string(round-half-to-even($val div 1.0E6,3)),"m")
      else if ($aval > 1.0E3) then concat(string(round-half-to-even($val div 1.0E3,3)),"k")
      else $aval
   return   
      if ($aval < 0) then <span style="color:red">{$scaled-value}</span> else <span>{$scaled-value}</span>
};

declare function wfn:between($x,$min,$max) {
  $x >= $min and $x <= $max
};

declare function wfn:BGR($max as xs:integer, $x as xs:integer?) as xs:string {
   let $x := ($x,0)[1]
   let $knee := $max * 0.4
   let $r := if ($x < $knee) then 0 else wfn:interpolate ($knee,0,$max,255,$x)
   let $g := if ($x < $knee) then wfn:interpolate (0,0,$knee,255,$x) else wfn:interpolate($knee,255,$max,0,$x)
   let $b := if ($x < $knee) then wfn:interpolate(0,255,$knee,0,$x) else 0
   return concat("#",wfn:int2-to-hex($r),wfn:int2-to-hex($g),wfn:int2-to-hex($b))
};

declare function wfn:camel-case-to-words ( $string as xs:string?)  as xs:string {
      if (upper-case($string) = $string) (:all uppercase letters :)
      then
         $string
      else
        concat(substring($string,1,1),
             replace(substring($string,2),'(\p{Lu})',
                        concat(" ", '$1')))     
};
 
declare function wfn:duration-as-ms($t) {
      round((minutes-from-duration($t) * 60 + seconds-from-duration($t)) * 1000 )
};

declare function wfn:exist-node-id-to-js-node-id($s as xs:string) as xs:string{
   concat("n-",replace($s,"\.","-"))
};

declare function wfn:external-host() {
  request:get-header("X-Forwarded-Host")
};

declare function wfn:index-of($nodes,$target) as xs:integer {    
  for $node at $i in $nodes
  return if ($node is $target) then $i else ()
};

declare function wfn:int-to-hex($n as xs:integer) as xs:string {
   if ($n <10) 
   then xs:string($n) 
   else  if ($n < 16)
   then ("A","B","C","D","E","F")[$n - 9 ]
   else "0"
};

declare function wfn:int2-to-hex($n as xs:integer) as xs:string {
  concat(wfn:int-to-hex($n div 16), wfn:int-to-hex($n mod 16))
};

declare function wfn:interpolate($x1 as xs:decimal,$y1  as xs:decimal,$x2  as xs:decimal,$y2  as xs:decimal,$x  as xs:decimal) as xs:integer{
  let $dx := $x2 - $x1
  let $dy := $y2 - $y1
  let $xp := $x - $x1
  let $yp := $xp * $dy div $dx 
  return xs:integer($y1 + $yp)
};

declare function wfn:is-even($n as xs:integer) {
  $n mod 2 = 0
};

declare function wfn:items-to-json($items) {
  concat(
      "{",
      string-join (
      for $item in $items
      return
        concat(name($item),': "', string($item),'"')
      , " , "
     ),
     "}" 
  )
};

declare function wfn:js-node-id-to-exist-node-id($s as xs:string) as xs:string{
   replace(substring-after($s,"n-"),"-",".")
};

declare function wfn:node-join($nodes,$sep) {
  if (count($nodes) > 1)
  then ($nodes[1],$sep, wfn:node-join(subsequence($nodes,2),$sep))
  else $nodes
};

declare function wfn:node-join($nodes,$sep1,$sep2) {
  if (count($nodes) > 2)
  then ($nodes[1],$sep1, wfn:node-join(subsequence($nodes,2),$sep1,$sep2))
  else if (count($nodes) =2)
  then ($nodes[1],$sep2,$nodes[2])
  else $nodes
};

(: more to do here :)
declare function wfn:paging($url as xs:string, $start as xs:integer, $pagesize as xs:integer, $max as xs:integer ) as element(div)?{
  let $pages := xs:integer(math:ceil($max div $pagesize) )
  let $page :=  math:floor($start div $pagesize) + 1
  let $prev-start := max(($start - $pagesize,1))
  let $next-start := $start + $pagesize
  return 
      if ($max eq 0) then ()
      else 
      <div class="paging">
       Page 
        <a href="{$url}&amp;start=1&amp;pagesize={$pagesize}">First</a>&#160;
       {if ($prev-start ne $start)
       then <a href="{$url}&amp;start={$prev-start}&amp;pagesize={$pagesize}">Previous</a>
       else "          "}
        {for $i in (1 to 10)
        let $start := xs:integer(($i - 1 ) * $pagesize + 1)
        return
          if ($i ne $page)
          then (<a href="{$url}&amp;start={$start}&amp;pagesize={$pagesize}">{$i}</a>,"&#160;")
          else concat("&#160;",$i,"&#160;")
       }
      {if ($next-start le $max)
       then <a href="{$url}&amp;start={$next-start}&amp;pagesize={$pagesize}">Next</a>
       else ()
       }
       <a href="{$url}&amp;start={$pages}&amp;pagesize={$pagesize}">Last</a>&#160;

      </div>
};


declare function wfn:paging-with-path($url as xs:string, $start as xs:integer, $pagesize as xs:integer, $max as xs:integer ) as element(div)? {
  let $pages := xs:integer(math:ceil($max div $pagesize) )
  let $page :=  math:floor($start div $pagesize) + 1
  let $prev-start := max(($start - $pagesize,1))
  let $next-start := $start + $pagesize
  let $q := if (contains($url,"?")) then "&amp;" else "?"
  let $links :=
       (if ($prev-start ne $start)
        then <a href="{$url}{$q}start={$prev-start}&amp;pagesize={$pagesize}">Previous</a>
        else <span>Previous</span>,
        for $i in (1 to $pages)
        let $start := xs:integer(($i - 1 ) * $pagesize + 1)
        return
          if ($i ne $page)
          then <a href="{$url}{$q}start={$start}&amp;pagesize={$pagesize}">{$i}</a>
          else <span>{$i}</span>
       ,
        if ($next-start le $max)
       then <a href="{$url}{$q}start={$next-start}&amp;pagesize={$pagesize}">Next</a>
       else <span>Next</span>
       )
  return 
      if ($max eq 0) then ()
      else 
      <div class="paging">
       Page 
       {wfn:node-join($links, " | ")}
      </div>
};

declare function wfn:paging-with-path2($url as xs:string, $start as xs:integer, $pagesize as xs:integer, $max as xs:integer ) as element(div)? {
  let $q := if (contains($url,"?")) then "&amp;" else "?"
  let $pages := xs:integer(math:ceil($max div $pagesize) )
  let $page :=  xs:integer(math:floor($start div $pagesize) + 1)
  let $prev-start := max(($start - $pagesize,1))
  let $next-start := $start + $pagesize
  let $start-pages := 1 to min((3,$pages))
  let $end-pages :=  max(($pages - 2 ,1)) to $pages 
  let $around-pages :=  max(($page - 2, 1))  to min(($page + 2,$pages))
  let $all-pages := distinct-values(($start-pages,$around-pages,$end-pages))
  let $links :=
       (if ($prev-start ne $start)
        then <a href="{$url}{$q}start={$prev-start}&amp;pagesize={$pagesize}">Previous</a>
        else <span>Previous</span>
        ,
        for $n at $i in $all-pages
        let $start := ($n - 1 ) * $pagesize + 1
        let $link := 
            if ($n ne $page)
            then <a href="{$url}{$q}start={$start}&amp;pagesize={$pagesize}">{$n}</a>
            else <span>{$n}</span>
        let $spacer := 
            if ($n > 2 and $n < $pages and $all-pages[$i + 1] ne $n + 1)
            then "..."
            else ()
        return ($link,$spacer)  
       ,
       if ($next-start le $max)
       then <a href="{$url}{$q}start={$next-start}&amp;pagesize={$pagesize}">Next</a>
       else <span>Next</span>
       )
  return 
      if ($max eq 0) then ()
      else 
      <div class="paging">
       Page 
       {wfn:node-join($links, " | ")}
      </div>
};


declare function wfn:permutations($items as item()*) as element(perm)+ {  
   let $itemElems := for $i in $items return <item>{$i}</item>
   return wfn:permutations-x($itemElems)
};
  
declare function wfn:permutations-x($items as element(item)*) as element(perm)+ {
   if (count($items) le 1) 
   then  element perm {$items}
   else 
      for $item in $items,
          $perm in wfn:permutations-x($items except $item)
      return element perm {($item,$perm/node())}    
 };

(:
  replacements is a sequence of:
      <replace find="ss" replace="rr"/>
:)
declare function wfn:replace($text,$replacements as element(replace)*) {
   if (empty($replacements))
   then $text
   else
      let $r := $replacements[1]
      let $rtext := fn:replace($text,$r/@find,$r/@replace) 
      return wfn:replace($rtext , subsequence($replacements,2))
};

declare function wfn:round($v as xs:decimal , $p as xs:integer) as xs:double {
    let $f := math:power(10,$p)
    return  round($v * $f) div $f
};

declare function wfn:round-attributes($e , $p as xs:integer)  {
   element  {node-name($e)}  {
       for $a in $e/@*
       return
           attribute {local-name($a)} {wfn:round($a,$p)}
     }
};

declare function wfn:split($s,$delimiter, $name, $fields) {
  let $d := tokenize($s,$delimiter)
  return
    element {$name} {
      for $field at $i in tokenize($fields,",")
      where $field ne ""
      return
         element {$field} {$d[$i]}
    }
};

declare function wfn:string-distance($arg1 as xs:string, $arg2 as xs:string) as xs:decimal {
let $range := (0 to string-length($arg1))
return
        wfn:string-distance(
               string-to-codepoints($arg1), 
               string-to-codepoints($arg2),
               1, 
               1,
               $range,
               1
          )
}; 

declare function wfn:string-distance($chars1 as xs:integer*, $chars2 as xs:integer*, $i1 as xs:integer, $i2 as xs:integer, $lastRow as xs:integer+, $thisRow as
        xs:integer+) as xs:decimal {
    if ($i1 > count($chars1)) 
    then 
        if ($i2 = count($chars2))
        then $thisRow[last()] 
        else wfn:string-distance($chars1, $chars2, 1, $i2 + 1, $thisRow, $i2 + 1 )
    else wfn:string-distance($chars1, $chars2, $i1 + 1, $i2, $lastRow, ($thisRow, min(($lastRow[$i1 +
        1] + 1, $thisRow[last()] + 1, $lastRow[$i1] + (if ($chars1[$i1] = $chars2[$i2]) then 0 else
        1) ) ) ) ) 
};

declare function wfn:string-pad($s as xs:string, $n as xs:integer) {
string-join(for $i in 1 to $n return $s,"")
};

declare function wfn:string-join($strings,$sep1,$sep2) {
 if (count($strings) > 1)
 then   concat(string-join($strings[position()<last()],$sep1),$sep2,$strings[last()])
 else $strings
};

declare function wfn:string-join($strings) {
  wfn:string-join($strings,", "," and ")
};

declare function wfn:substring-between($t,$start,$end) {
   normalize-space(substring-before(substring-after($t,$start),$end))
};

declare function wfn:upper-case-words ( $string as xs:string)  as xs:string {
       string-join(
            for $word in tokenize($string," ")
            return concat(upper-case(substring($word,1,1)),
                                lower-case(substring($word,2))
                                )
            ," "
            )
 } ;

(:
  replacements is a sequence of:
      <replace find="ss" replace="rr"/>
:)

declare function wfn:word-replace($text, $replacements as element(replace)*) {
   string-join(for $word in tokenize(normalize-space($text),"\s+")
               let $replacement := $replacements[@find=$word]/@replace
               return if ($replacement) then string($replacement) else $word
               ," "
               )
};
declare function wfn:table-to-html($root) {
let $headers  :=  $root/*[1]/*/name(.)
return
  <table border="1" class="sortable">
    <thead>
      <tr>
        {for $header in $headers
         return <th>{$header}</th> 
        }
      </tr>
    </thead>
    <tbody>
      {for $row in $root/*
       return
         <tr>
            {for $col in $row/*
             return <td>{$col/text()}</td> 
        } 
         </tr>
      }
    </tbody>
   </table>
 };

declare function wfn:table-to-html($root, $schema) {
  <table border="1">
    <thead>
      <tr>
        {for $column in $schema/column
         return <th>{string(($column/@label,$column/@name)[1])}</th> 
        }
      </tr>
    </thead>
    <tbody>
      {for $row in $root/*
       return
         <tr>
            {for $column in $schema/column
             let $data := string($row/*[name(.) = $column/@name])
             return <td>{$data}</td> 
            } 
         </tr>
      }
    </tbody>
   </table>
 };

declare function wfn:element-to-nested-table($element) {
  wfn:element-to-nested-table($element,1)
};

declare function wfn:element-to-nested-table($element,$n as xs:integer) {
    if (exists ($element/(@*|*)))
    then 
     <table  class="level{$n}">
        {if (exists($element/text()))
         then <tr  class="text">
                       <th ></th>
                       <td >{$element/text()}</td>
                   </tr>
         else ()
       }
       {for $attribute in $element/@*
       return
         <tr   class="attribute">
              <th>@{name($attribute)}</th>
              <td>{string($attribute)}</td>
         </tr>
       }
       {for $node in $element/*
       return 
            <tr   class="element">
                 <th>{name($node)}</th> 
                 <td>
                    { wfn:element-to-nested-table($node, $n + 1 )    }
                   </td>
             </tr>       
        }
    </table>
    else  
       $element/text() 
  };
  
declare function wfn:element-to-csv($element) as xs:string {
(: returns a  multi-line string of comma delimited strings  :)
let $sep := ","
return
string-join(
  (string-join($element/*[1]/*/name(.),$sep),
   for $row in $element/*
       return
         string-join(
          for $node in $element/*[1]/*
          let $data := string($row/*[name(.)=name($node)])
          return
               if (contains($data,$sep))
               then concat('"',$data,'"')
               else $data
           , $sep)
   ),"&#10;" )
};

declare function wfn:element-to-csv($element, $schema) as xs:string {
(: returns a  multi-line string of comma delimited strings  :)

string-join(
   ( string-join(
         for $column in $schema/column
         return string(($column/@label,$column/@name)[1]),",")
   ,
   for $row in $element/*
       return
         string-join(
          for $column in $schema/column
          let $data := string($row/*[name(.)= $column/@name])
          return
               if (contains($data,","))
               then concat('"',$data,'"')
               else $data
           , ",")
   ),"&#10;" )
};
