module namespace num = "http://kitwallace.me/num";

declare variable $num:DecimalSeparator := ".";
declare variable $num:GroupSeparator := ",";
declare variable $num:ZeroDigit := "0";
declare variable $num:Digit := "#";
declare variable $num:FormatPercent := "%";

declare variable $num:GroupSeparatorCode := string-to-codepoints($num:GroupSeparator)[1];
declare variable $num:ZeroDigitCode := string-to-codepoints($num:ZeroDigit)[1];
declare variable $num:DigitCode := string-to-codepoints($num:Digit)[1];

declare function num:format-number($inputNumber as xs:decimal, $inputFormat as xs:string) as xs:string
{
    let $patterns := tokenize($inputFormat, ";")  (: handle negative pattern :)
    let $format := if (count($patterns) = 1) then $inputFormat else if ($inputNumber > 0) then $patterns[1] else $patterns[2]
    (: if there is a pattern for negative numbers, let it handle the negative sign  :)
    let $number1 as xs:decimal := if (count($patterns) = 1) then $inputNumber else if ($inputNumber > 0) then $inputNumber else -($inputNumber)
    (: if the pattern doesn't include a decimal separator, round the number :)
    let $number as xs:decimal := if(contains($format, $num:DecimalSeparator)) then $number1 else round($number1)
    let $strNumber := string(
                        if (ends-with($format, $num:FormatPercent)) then $number*100 else $number
                    )
    let $decimalPart := codepoints-to-string(
                            num:format-number-decimal(
                                string-to-codepoints( substring-after($strNumber, '.') ),
                                string-to-codepoints( substring-after($format, $num:DecimalSeparator) )
                            )
                        )
    let $integerPart := codepoints-to-string(
                            num:format-number-integer(
                                reverse(
                                    string-to-codepoints(
                                        if(starts-with($strNumber, "0.")) then
                                            ""
                                        else
                                            if( contains($strNumber, '.') ) then 
												substring-before($strNumber, '.') 
											else 
												$strNumber
                                    )
                                ),
                                reverse(
                                    string-to-codepoints(
                                        if( contains($format, $num:DecimalSeparator) ) then 
											substring-before($format, $num:DecimalSeparator) 
										else 
											$format
                                    )
                                ),
                                0, -1
                            )
                        )
    return
        if (string-length($decimalPart) > 0) then
            concat($integerPart, $num:DecimalSeparator, $decimalPart) 
        else
            $integerPart
};
declare function num:format-number-decimal($number as xs:integer*, $format as xs:integer*) as xs:integer*
{
    if ($format[1] = $num:DigitCode or $format[1] = $num:ZeroDigitCode) then
        if (count($number) > 0) then
            ($number[1], num:format-number-decimal(subsequence($number, 2), subsequence($format, 2)))
        else
            if ($format[1] = $num:DigitCode) then () else ($format[1], num:format-number-decimal((), subsequence($format, 2)))
    else
        if (count($format) > 0) then
            ($format[1], num:format-number-decimal($number, subsequence($format, 2)))
        else
            ()
};
declare function num:format-number-integer($number as xs:integer*, $format as xs:integer*, $thousandsCur as xs:integer, $thousandsPos as xs:integer) as xs:integer*
{
  if (count($number) = 1 and $number[1] = string-to-codepoints("-")) then $number
  else
    if( $thousandsPos > 0 and $thousandsPos = $thousandsCur and count($number) > 0) then
        (num:format-number-integer($number, $format, 0, $thousandsCur), $num:GroupSeparatorCode)
    else
        if ($format[1] = $num:DigitCode or $format[1] = $num:ZeroDigitCode) then
            if (count($number) > 0) then
                (num:format-number-integer(subsequence($number, 2), subsequence($format, 2), $thousandsCur+1, $thousandsPos), $number[1])
            else if ($format[1] = $num:DigitCode) then
                (num:format-number-integer((), subsequence($format, 2), $thousandsCur+1, $thousandsPos))
            else
                (num:format-number-integer((), subsequence($format, 2), $thousandsCur+1, $thousandsPos), $format[1])
        else
            if (count($format) > 0) then
                if ($format[1] = $num:GroupSeparatorCode) then
                    if (count($number) = 0 and $format[2] != $num:ZeroDigitCode) then
                        (num:format-number-integer($number, subsequence($format, 2), 0, $thousandsCur))
                    else
                        (num:format-number-integer($number, subsequence($format, 2), 0, $thousandsCur), $format[1])
                else (: some other character :)
                    if (count($number) > 0) then (: digits come first of any other character in $format :)
                        (num:format-number-integer(subsequence($number, 2), $format, $thousandsCur+1, $thousandsPos), $number[1])
                    else
                        (num:format-number-integer($number, subsequence($format, 2), $thousandsCur+1, $thousandsPos), $format[1])
            else
                if (count($number) > 0) then
                    (num:format-number-integer(subsequence($number, 2), $format, $thousandsCur+1, $thousandsPos), $number[1])
                else
                    ()
};
