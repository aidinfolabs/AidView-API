(:
    Module: functions for formatting an xs:dateTime value.
    
    modified 21 May to remove use of item-at - now removed 
:)
module namespace date="http://kitwallace.me/date";

declare variable $date:months :=
	("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct","Nov", "Dec");
	
declare variable $date:otherMonths :=
	("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sept", "Oct","Nov", "Dec");

declare variable $date:fullMonths :=
	("January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
	"November", "December");

declare variable $date:days :=
  ( "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday");

declare variable $date:shortDays :=
  ( "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun");

declare function date:year-calendar ($year,$f) {
   <table>
     {for $r in 1 to 4
      return
      <tr>
      {
      for $c in 1 to 3
      let $m := ($r - 1) * 3 + $c
      let $month := date:zero-pad($m)
      return
         <td>{date:month-calendar($year,$month,$f)}</td>
      }
      </tr>
     }
   </table>

};

declare function date:month-calendar ($year,$month,$f) {
let $yearmonth := concat($year,"-",$month)
let $month-day1 := xs:date(concat($yearmonth,"-01"))
let $month-day1-weekday := datetime:day-in-week($month-day1)
let $days := datetime:days-in-month($month-day1)
let $offset := $month-day1-weekday -1
let $weeks  := xs:integer(math:ceil (($days + $offset) div 7 ))
return
<div>
  <table>
    <tr><th colspan="7">{$date:fullMonths[xs:integer($month)]}&#160;{$year}</th></tr>
    <tr>
      <th>Sun</th>
      <th>Mon</th>
      <th>Tue</th>
      <th>Wed</th>
      <th>Thu</th>
      <th>Fri</th>
      <th>Sat</th>
    </tr>
    <tr>
      {for $n in 1 to $offset
       return <td/>
      }
      {for $n in 1 to 7 - $offset
       let $day := date:zero-pad($n)
       let $date := concat($yearmonth,"-",$day)
       let $val := util:call($f,$date)
       return 
          $val
      }
   </tr>
   {for $week in (0 to $weeks - 1)
    let $sun := $week * 7 + 8 - $offset 
    return
      <tr>
        {
        for $n in  ($sun to $sun + 6) 
        return 
           if ($n le $days) 
           then      
              let $day := date:zero-pad($n)
              let $date := concat($yearmonth,"-",$day)
              let $val := util:call($f,$date)
              return 
                 $val
           else ()
        }
      </tr>
   }
 </table>
 </div>
};

declare function date:normalize-time($t){
 let $t := normalize-space($t)
 return
  if (matches($t,"^\d\d:\d\d$"))
  then $t
  else if (matches($t,"^\d\d\d\d$"))
  then concat(substring($t,1,2),":",substring($t,3,2))
  else if (matches($t,"^\d\d\d$"))
  then concat ("0",substring($t,1,1),":",substring($t,2,2))
  else if (matches($t,"^\d\.\d\d$"))
  then concat ("0",substring($t,1,1),":",substring($t,3,2))
  else if (matches($t,"^\d\:\d\d$"))
  then concat ("0",substring($t,1,1),":",substring($t,3,2))
  else  if (matches($t,"^\d\d\.\d\d$"))
  then concat (substring($t,1,2),":",substring($t,4,2))
  else ()
};

declare function date:dow-offset($date,$dow) {
   let $downo := index-of($date:days,$dow) - 1
   let $offset := concat("P",$downo,"D")
   return $date + xs:dayTimeDuration($offset)
};

declare function date:daySuffix($n as xs:decimal) as xs:string {
    if ($n =(1,21,31)) then "st"
    else if ($n = (2,22)) then "nd"
    else if ($n = (3,23)) then "rd"
    else "th"
};

declare function date:zero-pad($i) as xs:string {
	if(xs:integer($i) lt 10) then
		concat("0", $i)
	else
		xs:string($i)
};

declare function date:dayOfWeekNo($date) {
(: Monday is 1 :)
    let $day := xs:date($date) - xs:date('2005-01-03')
    return days-from-duration($day) mod 7 + 1
};

(:  conversion from string to date and time :)
declare function date:from-ddmmyyyy-slash($date as xs:string )  as xs:date {
(: 20/01/2007   :)
   let $date := normalize-space($date)
   let $date := tokenize($date,"/")
   return xs:date(concat($date[3],'-',$date[2],'-',$date[1]))
};

declare function date:from-dd-mmm-yy($d) {
 (: eg 20 Jan 2001  or 20 January 2011 or Jan 20 2010 :)
if (matches ($d,"\d+\s+\w+\s+\d+"))
then 

  let $dp := tokenize($d,"\s+")
  let $day := $dp[1]
  let $m := $dp[2]
  let $month := (index-of($date:months,$m), index-of($date:fullMonths,$m),index-of($date:otherMonths,$m))[1]
  let $year := $dp[3]
  let $year := if (string-length($year) = 2) then if (xs:integer($year) <50) then concat("20",$year) else concat("19",$year) else $year
  let $date := concat($year,"-",date:zero-pad($month),"-",date:zero-pad($day))
  return 
    if ($date castable as xs:date ) then $date else ()
 else
  if (matches ($d,"\w+\s+\d+\s+\d+"))
  then 
  let $dp := tokenize($d,"\s+")
  let $day := $dp[2]
  let $m := $dp[1]
  let $month := (index-of($date:months,$m), index-of($date:fullMonths,$m),index-of($date:otherMonths,$m))[1]
  let $year := $dp[3]
  let $year := if (string-length($year) = 2) then if (xs:integer($year) <50) then concat("20",$year) else concat("19",$year) else $year
  let $date := concat($year,"-",date:zero-pad($month),"-",date:zero-pad($day))
  return 
    if ($date castable as xs:date ) then $date else ()
 else ()
};

declare function date:datetime-to-RFC-822($date) as xs:string {
  datetime:format-dateTime($date,"E, dd MMM yyyy H:m:s z")
};

declare function date:RFC-822-to-date($date as xs:string) as xs:date {
  let $d := tokenize($date,"\s")
  let $month := (index-of($date:months,$d[3]),1)[1]
  let $month := date:zero-pad($month)
  let $day :=  xs:integer($d[2])
  let $day := date:zero-pad($day)
  return concat($d[4],"-",$month,"-",$day)
};
declare function date:RFC-822-to-dateTime($date as xs:string) as xs:dateTime  {
  let $d := tokenize($date,"\s")
  let $month := (index-of($date:months,$d[3]),1)[1]
  let $month := date:zero-pad($month)
  let $day :=  xs:integer($d[2])
  let $day := date:zero-pad($day)
  let $time := $d[5] 
  let $time := if (string-length($time) = 7) then concat("0",$time) else $time
  return xs:dateTime(concat($d[4],"-",$month,"-",$day,"T",$time))
};

declare function date:from-ddmmmyyyytime($date as xs:string) {
(: e.g. 20 Jan 2011 21:45 :)
  let $d := tokenize(normalize-space($date)," ")
  let $month := date:zero-pad(index-of($date:months,$d[2]))
  let $day := date:zero-pad($d[1])
  return concat($d[3],"-",$month,"-",$day,"T",$d[4],":00Z")
};

declare function date:from-dowddmmmyyyytime($date as xs:string) {
(: e.g.  Sun, 20 Jan 2011 21:45:56 +0000 :)
  let $date := substring-after($date,",")
  let $d := tokenize(normalize-space($date)," ")
  let $month := date:zero-pad(index-of($date:months,$d[2]))
  let $day := date:zero-pad($d[1])
  return concat($d[3],"-",$month,"-",$day,"T",$d[4],"Z")
};

declare function date:from-ddMonthYear($date) as xs:date {
(: 20 January 2007 :)
   let $dp := tokenize($date," ")
   let $month := date:zero-pad(index-of($date:months,dp[2]))
   let $ds := string-join(($dp[3],date:zero-pad(number($month)),date:zero-pad(number($dp[1]))),'-')
   return xs:date($ds)
};

declare function date:from-hhmm($time as xs:string)  as xs:time {
   let $time := tokenize($time,":")
   let $min :=  if (string-length($time[1]) <2) then concat("0",$time[1]) else $time[1]
   return  xs:time(concat($min,":",$time[2],":00"))
};

declare function date:from-dmyy($date as xs:string )  as xs:date {
(: 20/1/07   - assume in 2000 century :)
   let $date := normalize-space($date)
   let $date := tokenize($date,"/")
   let $year := concat("20",$date[3])
   let $month := if (string-length($date[2])<2) then concat("0",$date[2]) else $date[2]
   let $day := if (string-length($date[1])<2) then concat("0",$date[1]) else $date[1]
   return xs:date(concat($year,'-',$month,'-',$day))
};

declare function date:from-ddMMMyy($d as xs:string){
(: 20-Mar-95 :)
  let $d := normalize-space($d)
  let $dp := tokenize($d,"-")
  let $mn := index-of($date:months,$dp[2])
  let $mn := if ($mn <10) then concat("0",$mn) else xs:string($mn)
  let $dn := if (string-length($dp[1]) < 2 ) then concat("0",$dp[1]) else $dp[1]
  let $dy := xs:integer($dp[3])
  let $dyc := if ($dy <10) then concat("0",$dy) else xs:string($dy)
  let $dy := if ($dy > 20 ) then concat("19",$dyc) else concat("20",$dyc)
  return 
    string-join(($dy,$mn,$dn),"-")
};


(: operations on dates :)

declare function date:first-of-month($d as xs:date) {
  $d - xdt:dayTimeDuration(concat("P",day-from-date($d) -1,"D"))
};

declare function date:last-of-month($d as xs:date) {
  date:first-of-month($d  + xdt:yearMonthDuration("P1M")) - xdt:dayTimeDuration("P1D")
};



(:   conversions from xs:date xs:time to string :)
(: most of these could be replaced by usage of a general data formater :)

declare function date:to-monddyyyy($date as xs:date) as xs:string {
(:  e.g. Jan 20 2007  :)
    string-join((
             $date:months[ month-from-date($date)],
             day-from-date($date),
             year-from-date($date)), " ")
}; 

declare function date:to-dowdayMon($date as xs:date) as xs:string {
(: e.g Wed 20 Jan :)
	string-join((
	               $date:shortDays[date:dayOfWeekNo($date)],
                              day-from-date($date),
		$date:months[month-from-date($date)]
		), " ")
};

declare function date:to-dayMonthYear($date as xs:date) as xs:string {
(: e.g 20st January 2007 :)
	string-join((	
               concat(day-from-date($date),date:daySuffix(day-from-date($date))), 
		$date:fullMonths[month-from-date($date)],
		year-from-date($date)), " ")
};

declare function date:to-ddmmyyyySlash($date as xs:date) as xs:string {
(: e.g. 20/01/2007 :)
           string-join((day-from-date($date),month-from-date($date),year-from-date($date)),'/')
};


declare function date:to-hhmmss($time as xs:time) as xs:string {
(: e.g.  12:45:34  :)
	string-join((
		date:zero-pad(hours-from-dateTime($time)), 
		date:zero-pad(minutes-from-dateTime($time)), 
		date:zero-pad(xs:integer(seconds-from-dateTime($time)))
		),':'	
	)
};

declare function date:to-vcal-datetime($date as xs:date,$time as xs:time) as xs:string {
   let $date := tokenize($date,"-")
   let $time := tokenize($time,":")
   return concat($date[1],$date[2],$date[3],"T",$time[1],$time[2],$time[3],"Z")
};

declare function date:wikidate($date as xs:date) as xs:string {
      concat(year-from-date($date),"_",
             $date:fullMonths[month-from-date($date)],"_",
             day-from-date($date)
             )
};

