module namespace  str = "http://kitwallace.me/string";
declare namespace transform ="http://exist-db.org/xquery/transform";

declare variable $str:nl := "&#10;";
declare variable $str:cr := "&#13;";

declare function str:substring-between($t,$start,$end) {
   normalize-space(substring-before(substring-after($t,$start),$end))
};

declare function str:camel-case-to-words ( $string as xs:string?)  as xs:string {
        concat(substring($string,1,1),
             replace(substring($string,2),'(\p{Lu})',
                        concat(" ", '$1')))
 } ;

declare function str:upper-case-words ( $string as xs:string)  as xs:string {
       string-join(
            for $word in tokenize($string," ")
            return concat(upper-case(substring($word,1,1)),
                                lower-case(substring($word,2))
                                )
            ," "
            )
 } ;
 
declare function str:string-join($strings,$sep1,$sep2) {
 if (count($strings) > 1)
 then   concat(string-join($strings[position()<last()],$sep1),$sep2,$strings[last()])
 else $strings
};

declare function str:string-join($strings) {
  str:string-join($strings,", "," and ")
};

declare function str:distance($arg1 as xs:string, $arg2 as xs:string) as xs:decimal {
let $range := (0 to string-length($arg1))
return
        str:distance(
               string-to-codepoints($arg1), 
               string-to-codepoints($arg2),
               1, 
               1,
               $range,
               1
          )
}; 

declare function str:distance($chars1 as xs:integer*, $chars2 as xs:integer*, $i1 as xs:integer, $i2 as xs:integer, $lastRow as xs:integer+, $thisRow as
        xs:integer+) as xs:decimal {
    if ($i1 > count($chars1)) 
    then 
        if ($i2 = count($chars2))
        then $thisRow[last()] 
        else str:distance($chars1, $chars2, 1, $i2 + 1, $thisRow, $i2 + 1 )
    else str:distance($chars1, $chars2, $i1 + 1, $i2, $lastRow, ($thisRow, min(($lastRow[$i1 +
        1] + 1, $thisRow[last()] + 1, $lastRow[$i1] + (if ($chars1[$i1] = $chars2[$i2]) then 0 else
        1) ) ) ) ) 
};

(:
declare function str:fuzzy-match($targets, $arrow,$threshold) {
   let $min := min (for $s in $targets return str:distance($s,$arrow))
   return
     if ($min le $threshold)
     then 
        $targets[ str:distance(., $arrow) = $min][1]
     else 
        ()
};
:)

declare function str:analyse-string($data as xs:string, $pattern as xs:string, $names as xs:string+ ) as element(data) {
   let $target := string-join(for $i in (1 to count($names)) return concat ("$",$i),":")
   let $filledTarget := replace($data,$pattern,$target)
   return
   <data>
     { for $string at $i in tokenize($filledTarget,":")
       return 
         element {$names[$i]} {normalize-space($string)}
     }
   </data>
};

declare function str:analyze-string($string as xs:string, $regex as xs:string,$n as xs:integer ) {

(:~  
      Use the XSLT2 function analyze-string to locate substrings matching subexpressions in a regular expression.
      
      This works by generating an XSLT stylesheet which is processed via the eXist transform:transform function 

      @param $string tthe string to be analysed
      @param $regex the regular expression containing parenthised sub expressions
      @n the number of subexpressions to be returned 
      
      @return a  sequence of match elements containing the matched expressions 
:)

 transform:transform   
(<any/>, 
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"> 
   <xsl:template match='/' >  
      <xsl:analyze-string regex="{$regex}" select="'{$string}'" > 
         <xsl:matching-substring>
            <xsl:for-each select="1 to {$n}"> 
               <match>  
                   <xsl:value-of select="regex-group(.)"/>  
                </match>  
             </xsl:for-each> 
          </xsl:matching-substring> 
      </xsl:analyze-string>  
   </xsl:template> 
</xsl:stylesheet>,
()
)
};

declare function str:format-number($number as xs:decimal, $format as xs:string) as xs:string
{
	let $strNumber := string(
						if (ends-with($format, "%")) then $number*100 else $number
					)
	let $decimalPart := codepoints-to-string(
							str:format-number-decimal(
								string-to-codepoints( substring-after($strNumber, ".") ),
								string-to-codepoints( substring-after($format, ".") )
							)
						)
	let $integerPart := codepoints-to-string(
							str:format-number-integer(
								reverse(
									string-to-codepoints(
										if(starts-with($strNumber, "0.")) then
											""
										else
											if( contains($strNumber, ".") ) then substring-before($strNumber, ".") else $strNumber
									)
								),
								reverse(
									string-to-codepoints(
										if( contains($format, ".") ) then substring-before($format, ".") else $format
									)
								),
								0, -1
							)
						)
	return
		if (string-length($decimalPart) > 0) then
			concat($integerPart, ".", $decimalPart) 
		else
			$integerPart
};

declare function str:format-number-decimal($number as xs:integer*, $format as xs:integer*) as xs:integer*
{
	if ($format[1] = 35 or $format[1] = 48) then
		if (count($number) > 0) then
			($number[1], str:format-number-decimal(subsequence($number, 2), subsequence($format, 2)))
		else
			if ($format[1] = 35) then () else ($format[1], str:format-number-decimal((), subsequence($format, 2)))
	else
		if (count($format) > 0) then
			($format[1], str:format-number-decimal($number, subsequence($format, 2)))
		else
			()
};

declare function str:format-number-integer($number as xs:integer*, $format as xs:integer*, $thousandsCur as xs:integer, $thousandsPos as xs:integer) as xs:integer*
{
	if( $thousandsPos > 0 and $thousandsPos = $thousandsCur and count($number) > 0) then
		(str:format-number-integer($number, $format, 0, $thousandsCur), 44)
	else
		if ($format[1] = 35 or $format[1] = 48) then
			if (count($number) > 0) then
				(str:format-number-integer(subsequence($number, 2), subsequence($format, 2), $thousandsCur+1, $thousandsPos), $number[1])
			else
				if ($format[1] = 35) then () else (str:format-number-integer((), subsequence($format, 2), $thousandsCur+1, $thousandsPos), $format[1])
		else
			if (count($format) > 0) then
				if ($format[1] = 44) then
					(str:format-number-integer($number, subsequence($format, 2), 0, $thousandsCur), $format[1])
				else
					(str:format-number-integer($number, subsequence($format, 2), $thousandsCur+1, $thousandsPos), $format[1])
			else
				if (count($number) > 0) then
					(str:format-number-integer(subsequence($number, 2), $format, $thousandsCur+1, $thousandsPos), $number[1])
				else
					()
};

