module namespace convert = "http://kit.wallace.me/convert";

declare function convert:direction-to-compass ($dir) {
let $dp :=  xs:integer($dir) + 11.25 
let $dp := if ($dp >=360) then $dp - 360 else $dp
let $p := floor($dp div 22.5)+ 1
return 
  ("N","NNE","NE","ENE","E","ESE","SE" ,"SSE" ,"S", "SSW","SW","WSW","W", "WNW","NW","NNW","N")[$p]
};

declare function convert:vapour-pressure ($temp) {
 6.11 * math:power(10,7.5 * $temp div ($temp + 237.7))
};

declare function convert:humidity($temp,$dew-point) {
 round(convert:vapour-pressure($dew-point) div convert:vapour-pressure($temp) * 100)
};

declare function convert:f-to-c($temp) {
   round((xs:decimal($temp) - 32) * 5 div 9)
};
declare function convert:zero-pad($n) {
  if ($n < 10) then concat("0",$n) else $n
};


declare function convert:ampm-to-time ($ampm) {
   let $time := tokenize ($ampm," ")
   let $thm := tokenize($time[1],":")
   let $t := xs:integer($thm[1]) + xs:integer($thm[2]) div 60 
   let $t := if ($time[2]= "AM" and $t lt 12) then $t 
             else if ($time[2] = "AM" and $t ge 12) then $t - 12
             else if ($time[2] = "PM" and $t lt 12) then $t + 12 
             else if ($time[2] = "PM" and $t ge 12) then $t
             else ()
   let $h := floor($t)
   let $m := round(($t - $h) * 60 )
   return concat (convert:zero-pad($h),":",convert:zero-pad($m))
};
