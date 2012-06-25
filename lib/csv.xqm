module namespace csv = "http://kitwallace.me/csv";

declare variable $csv:newline:= "&#10;";  
declare variable $csv:tab := "&#9;";    


declare function csv:substring-between($s,$start,$end) {
   let $substring := 
         if (empty($start)) then substring-before($s,$end)
         else if (empty($end)) then substring-after($s,$start)
         else substring-before(substring-after($s,$start),$end)
  return normalize-space($substring)
};

declare function csv:get-html($uri as xs:string) {
   let $headers := element headers { element header {attribute name {"Pragma" }, attribute value {"no-cache"}}}
   let $response := httpclient:get(xs:anyURI($uri), true(), $headers)	
   return  
       if  ($response/@statusCode eq "200")
       then 
            $response/httpclient:body 
      else ()
};

declare function csv:parse-csv($s) {
 if (contains($s,'"') or contains($s,','))
 then
  if (starts-with($s,'"'))
  then let $ss := csv:substring-between($s,'"','"')
           let $rem := substring-after(substring-after($s,$ss),",")
           let $x := csv:parse-csv($rem)
           return ($ss,$x)
  else  
          let $ss := substring-before($s,",")
          let $rem := substring-after($s,",")
          let $x := csv:parse-csv($rem)
          return ($ss,$x)
  else $s
};

declare function csv:parse-csv($s, $delimiter) {
 if (contains($s,'"') or contains($s,$delimiter))
 then
  if (starts-with($s,'"'))
  then let $ss := csv:substring-between($s,'"','"')
           let $rem := substring-after(substring-after($s,$ss),$delimiter)
           let $x := csv:parse-csv($rem,$delimiter)
           return ($ss,$x)
  else  
          let $ss := substring-before($s,$delimiter)
          let $rem := substring-after($s,$delimiter)
          let $x := csv:parse-csv($rem,$delimiter)
          return ($ss,$x)
  else $s
};
declare function csv:parse-row($s,$delimiter) {
   if ($delimiter = ",")
   then csv:parse-csv($s)
   else tokenize($s,$delimiter)
};

(:~
   : Get a file via HTTP and convert the body of the HTTP response to text
   : force the script to get the latest version using the HTTP Pragma header
   : @param uri  - URI of the text file to read
   : @param binary - true if data is base64 encoded
   : @return  -  the body of the response as text
:)

declare function csv:get-web-data ($uri as xs:string)  as xs:string? {
    let $headers := element headers { element header {attribute name {"Pragma" }, attribute value {"no-cache"}}}
    let $random := math:random()   
    let $response := httpclient:get(xs:anyURI(concat($uri,if (contains($uri,'?')) then concat("&amp;xyz=",$random) else concat("?xyz=",$random))), true(), $headers)	
	return  
	   if ($response/@statusCode eq "200")
	   then 
	            let $raw := $response/httpclient:body 
	            let $mode := $response//httpclient:header[@name="Content-Type"]/@value
	            return 
	            if ($mode=("application/octet-stream","text/csv"))     (: this is a hack to get air quality going - needs analysis :)
	            then util:binary-to-string($raw)
	            else xmldb:decode($raw)
	   else ()
};

(:  convert using a configuration file 

   <config name="name">
      <root>root element name</root>
      <skipheaders> start at the following row
      <delimiter>delimiter 
      <row>row element name
      <columns>
        <var name="name of variable"  datatype="datatype of variable string,decimal," format="pattern to validate format of data"  compute="conversion rule as XQuery" >
        
      </columns>
      <requires>rule to validate whole row
   </config>
:)

declare function csv:convert-with-config($csv as xs:string , $config as element(config)) {
let $rows := tokenize($csv, $csv:newline)
return
   element  {$config/root}  { 
          $config/@name,
          $config/@source,
          attribute created {current-dateTime()},
          for $rowcsv in subsequence($rows, xs:integer($config/skipheaders) + 1)
          let $cols := csv:parse-row(normalize-space($rowcsv),$config/delimiter)  

          let $row :=
                element {$config/row} 
                   {if (empty($config/columns))
                    then
                      for $col at $i in $cols
                      return 
                         element {concat("col_",$i)} {normalize-space($col)}
                    else 
                    for $var in $config/columns/var
                    let $i := xs:integer($var/@col)
                    let $value := $cols[$i] 
                    let $value := normalize-space($value) 
                    let $valid := 
                         if ($var/@datatype) 
                         then if ($var/@datatype = "decimal") 
                              then $value castable as xs:decimal
                              else if ($var/@datatype = "integer")
                              then $value castable as xs:integer
                              else if ($var/@format) 
                              then matches($value,$var/@format)
                              else $value ne ""
                         else $value ne ""
                    let $value := 
                      if ($valid) 
                      then if ($var/@compute) 
                           then util:eval($var/@compute)
                           else $value
                      else ()
                    
                    return  
                       if (exists($value) or $var/@nullable = "true")
                       then 
                          element {$var/@name} { $value}
                       else () 
                    }

            return 
                 if (exists($config/requires))
                 then if (util:eval($config/requires))
                      then $row
                      else ()
                 else $row
          }
};

(:~
   : convert a simple CSV text file with column names in the first row to an XML tree
   : empty values are ignored
   : @param $uri - uri of data file
   : @param $rootname  - name for root element 
   : @param $rowname - name for row element
   : @param $delimiter  - field delimiter in a row
   : @param $colnames - names for columns
   : @param $start - index of  first data row 
   : @return an XML tree - cell nodes have element name taken for the column name
:)

declare function csv:convert-to-xml($csv as xs:string , $rootname as xs:string, $rowname as xs:string, $delimiter as xs:string, $colnames as xs:string*, $start as xs:integer? , $namecol as xs:integer, $callback as function?) {
let $rows := tokenize($csv, $csv:newline)
let $cellnames := 
   if (exists($colnames))
   then 
      if ($colnames="_generate")
      then 
         for $colname at $i  in  csv:parse-row($rows[$namecol],$delimiter)
         return concat("Col_",$i)
     else
       $colnames
   else 
       for $colname in  csv:parse-row($rows[$namecol],$delimiter)
       return 
             let $name := replace($colname,"\s|/|/$|/%", "")
             let $name := normalize-space($name)
             let $first := substring($name,1,1)
             return
                   if ($first castable as xs:integer)
                   then concat("X_",$name)
                   else $name
return
   element  {$rootname}  {      
          for $row in subsequence($rows,($start,1)[1])
          let $cols := csv:parse-row(normalize-space($row),$delimiter)
          return
                element {$rowname} 
                   {for $name at $i in $cellnames
                    let $val := $cols[$i] 
                    let $val :=  
                        if (exists($callback))
                        then 
                           util:call($callback,$val,$i,$name)
                        else  normalize-space($val) 
                    return  
                       if (exists($val) and $val ne "")
                       then 
                          element {$name} { $val}
                       else () 
                    }
          }
};

declare function csv:convert-to-xml($csv as xs:string , $rootname as xs:string, $rowname as xs:string,$delimiter as xs:string, $colnames as xs:string*, $start as xs:integer? , $callback as function?) {

let $rows := tokenize($csv, $csv:newline)
let $cellnames := 
   if (exists($colnames))
   then 
      if ($colnames="_generate")
      then 
         for $colname at $i  in  csv:parse-row($rows[1],$delimiter)
         return concat("Col_",$i)
     else
       $colnames
   else 
       for $colname in  csv:parse-row($rows[1],$delimiter)
       return 
             let $name := replace($colname,"\s|/|/$|/%", "")
             let $name := normalize-space($name)
             let $first := substring($name,1,1)
             return
                   if ($first castable as xs:integer)
                   then concat("X_",$name)
                   else $name
return
   element  {$rootname}  {      
          for $row in subsequence($rows,($start,1)[1])
          let $cols := csv:parse-row(normalize-space($row),$delimiter)
          return
                element {$rowname} 
                   {for $name at $i in $cellnames
                    let $val := $cols[$i] 
                    let $val :=  
                        if (exists($callback))
                        then 
                           util:call($callback,$val,$i,$name)
                        else  normalize-space($val) 
                    return  
                       if (exists($val) and $val ne "")
                       then 
                          element {$name} { $val}
                       else () 
                    }
          }
};

declare function csv:convert-to-xml($csv as xs:string , $rootname as xs:string, $rowname as xs:string,$delimiter as xs:string ,$colnames, $start-data as xs:integer) {
    csv:convert-to-xml($csv,$rootname,$rowname,$delimiter,$colnames,$start-data,())
};

declare function csv:convert-to-xml($csv as xs:string , $rootname as xs:string, $rowname as xs:string,$delimiter as xs:string) {
    csv:convert-to-xml($csv,$rootname,$rowname,$delimiter,(),2,())
};

declare function csv:convert-to-xml($csv as xs:string , $rootname as xs:string, $rowname as xs:string) {
    csv:convert-to-xml($csv,$rootname,$rowname,",",(),2,())
};

declare function csv:convert-to-xml($csv as xs:string) {
    csv:convert-to-xml($csv,"table","row",",",(),2,())
};

declare function csv:element-to-csv($element) as xs:string {

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
   ),$csv:newline )
};

declare function csv:table-to-csv($element) as xs:string {
(: convert HTML table  to csv :)
let $sep := ","
return
string-join(
  (string-join($element/tr[1]/*,$sep),
   for $row in $element/tr[position() > 1]
       return
         string-join((
          for $data in $row/*
          return
               if (contains($data,$sep))
               then concat('"',$data,'"')
               else $data)
           , $sep)
   ),$csv:newline )
};

