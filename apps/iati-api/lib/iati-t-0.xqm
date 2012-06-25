module namespace iati-t = "http://kitwallace.me/iati-t" ;
import module namespace iati-b ="http://kitwallace.me/iati-b" at "iati-b.xqm";
import module namespace iati-c ="http://kitwallace.me/iati-c" at "iati-c.xqm";
declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";


declare variable $iati-t:conversion-rates := doc(concat($iati-b:base,"currency/currency-conversion.xml"))/conversions/conversion;
declare variable $iati-t:qmonths := (1,1,1,2,2,2,3,3,3,4,4,4);
declare variable $iati-t:errors := doc(concat($iati-b:data ,"pipeline-errors.xml"))/errors;

declare function iati-t:add-default-sector-vocab($activity as element(iati-activity)) as element(iati-activity) {
   element iati-activity {
      $activity/@*,
      for $sector in $activity/sector
      return 
         element sector {
             $sector/@*,
             if (empty($sector/@vocabulary)) then attribute vocabulary {"DAC"} else (),
             $sector/node()
         },
      
      $activity/(* except sector)
    }
};


declare function iati-t:add-project-value($activity as element(iati-activity)) as element(iati-activity) {
let $value := 
 max( 
(for $type in ("C","D","E","IR","LR","R","IF")
return sum($activity/transaction[transaction-type/@code=$type]/value/@iati-ad:USD-value[. > 0]),
sum ($activity/budget/value/@iati-ad:USD-value[. > 0]),
sum ($activity/planned-disbursement/value/@iati-ad:USD-value[. > 0])
)
 )
return
   element iati-activity {
      $activity/@*,
      attribute iati-ad:project-value {$value},
      $activity/*
    }
};

declare function iati-t:convert-to-USD($nodes ,$default-currency) {
  for $node in $nodes
  return 
     typeswitch($node)
         case text() return $node
         case attribute() return $node
         case element(value) return
            let $value-currency := upper-case(
               if (exists($node/@currency) and $node/@currency ne "")
               then $node/@currency
               else $default-currency)
            let $date := if ($node/@iso-date and $node/@iso-date ne "")   (: this because of empty date strings everywhere :)
                         then $node/@isodate
                         else if ($node/@value-date and $node/@value-date ne "")
                         then $node/@value-date
                         else if ($node/../transaction-date/@iso-date and $node/../transaction-date/@iso-date ne "")
                         then $node/../transaction-date/@iso-date
                         else "2011-01-01"
            let $dp := tokenize($date,"-")
            let $year := $dp[1]
            let $month := xs:integer($dp[2])
            let $transaction := $node/..
            let $transaction-date :=( $transaction/transaction-date/@iso-date,$transaction/period-start/@iso-date,$date)[1]
            let $transaction-type := 
                  typeswitch ($transaction) 
                     case element(transaction) return $node/../transaction-type/@code
                     case element(budget) return "TB"
                     case element(planned-disbursement) return "PD"
                     default return ()
 (:           let $qtr := if (string-length($year)=4) then concat($year,"Q", $iati-t:qmonths[$month]) else () :)
            let $USD-value := 
             if ($value-currency eq "USD") 
             then $node/text()
             else iati-t:convert-value-to-USD($value-currency, $year ,$node)
            return
            element value {
               $node/@* ,
               if ($value-currency) then attribute iati-ad:currency {$value-currency} else (),
               attribute iati-ad:date {$date}, 
               attribute iati-ad:transaction-date {$transaction-date},
               attribute iati-ad:transaction-type {$transaction-type}, 
(:               if ($qtr) then attribute qtr {$qtr}  else (),  :)
               if ($USD-value) then attribute iati-ad:USD-value {$USD-value} else (),
               $node/node()
            }
         default return 
            element {node-name($node)} {
               $node/@*,
               iati-t:convert-to-USD($node/node(),$default-currency)
            }
};

declare function iati-t:convert-to-USD($activity as element(iati-activity)) as element(iati-activity) {
let $default-currency := ($activity/@default-currency,"USD")[1]
return 
    iati-t:convert-to-USD($activity,$default-currency)
};

(: conversion rate table contains rates of conversion from USD to the target currency 
   
:)
declare function iati-t:convert-value-to-USD($from-code, $year, $amount) {
let $year := if ($year > '2010') then '2010' else $year
let $rate-from := $iati-t:conversion-rates[@to-currency = $from-code][@year=$year][@from-currency = "USD"]/@rate
let $conv-amount :=  round(xs:double($amount) div xs:double($rate-from))
return
   ($conv-amount,0)[1]
};


declare function iati-t:add-DEC-3-sectors($activity as element(iati-activity)) as element(iati-activity) {
   element iati-activity {
      $activity/@*,

       for $code in distinct-values(
                  for $sector in $activity/sector[@vocabulary="DAC"]/@code
                  return iati-c:code-value("Sector",$sector)/category
                  )
       let $category := iati-c:code-value("SectorCategory",$code)
       let $percentage := sum($activity/sector[@vocabulary="DAC"][iati-c:code-value("Sector",@code)/category = $code]/(@percentage,100)[1])
       return 
       element sector {
             attribute code {$code},
             attribute vocabulary {"DAC-3"},
             attribute iati-ad:category {$code},
             attribute percentage {$percentage},
             attribute iati-ad:project-value {round($activity/@iati-ad:project-value * $percentage div 100)},
             $category/name/string()
       },  
       $activity/*
    }
};


(:
   original version 
declare function iati-t:add-project-value($activity as element(iati-activity)) as element(iati-activity) {
let $value := 
 max( 
(for $type in ("C","D","F","IR","LR","R","IF")
return sum($activity/transaction[transaction-type/@code=$type]/value[. > 0]),
sum ($activity/budget/value[. > 0]),
sum ($activity/planned-disbursements/value[. > 0])
)
 )
return
   element iati-activity {
      $activity/@*,
      attribute iati-ad:project-value {$value},
      $activity/*
    }
};

:)

declare function iati-t:add-wo-locations($activity as element(iati-activity)) as element(iati-activity) {
let $locations := collection($iati-b:base,"geo")//iati-activity[iati-identifier = $activity/iati-identifier]/location
return 
 if (exists($locations))
 then 
   element iati-activity {
      $activity/@*,
      $activity/*,
      $locations
    }
  else $activity
};

declare function iati-t:apportion-sector-value($activity as element(iati-activity) ) as element (iati-activity)? {
 let $value := number($activity/@iati-ad:project-value)
 return
   element iati-activity {
       $activity/@*,
       for $vocabulary in distinct-values($activity/sector/@vocabulary)
       let $sectors := $activity/sector[@vocabulary=$vocabulary]
       return 
          for $sector in $sectors
          let $percentage := if ($sector/@percentage castable as xs:integer) then xs:integer($sector/@percentage) else round(100 div count($sectors)) 
          return 
             element sector {
                  $sector/(@* except @percentage),
                  if ($sector[@vocabulary="DAC"]) then attribute iati-ad:sector {$sector/@code} else (),
                  attribute iati-ad:project-value {round($value * $percentage div 100)}, 
                  attribute percentage {$percentage},
                  $sector/node()
             },
        $activity/(* except sector)
   }
};

declare function iati-t:apportion-country-value($activity as element(iati-activity) ) as element (iati-activity)? {
 let $value := number($activity/@iati-ad:project-value)
 return
   element iati-activity {
       $activity/@*,

       for $country in $activity/recipient-country
       return 
             element recipient-country {
                 $country/@*,
                 attribute iati-ad:country {$country/@code},

                 attribute iati-ad:project-value {if ($country/@percentage ) then round($value * $country/@percentage div 100)  else $value},
                 $country/node()
             },
        $activity/(* except recipient-country)
   }
};

declare function iati-t:apportion-region-value($activity as element(iati-activity) ) as element (iati-activity)? {
 let $value := number($activity/@iati-ad:project-value)
 return
   element iati-activity {
       $activity/@*,
       for $region in $activity/recipient-region
       return 
             element recipient-region {
                 $region/@*,
                 attribute iati-ad:region {$region/@code},
                 attribute iati-ad:project-value {if ($region/@percentage ) then round($value * $region/@percentage div 100)  else $value},
                 $region/node()
             },
        $activity/(* except recipient-region)
   }
};

declare function iati-t:add-org-key($activity as element(iati-activity) ) as element (iati-activity)? {
    element iati-activity {
       $activity/@*,
       for $org in $activity/participating-org
       return 
             element participating-org {
                 $org/@*,
                 if ($org/@ref ne "") then attribute iati-ad:org {$org/@ref} else (),
                 if ($org/@ref ne "" and $org/@role="Funding") then attribute iati-ad:funder {$org/@ref} else (),
                 $org/node()
             },
        $activity/(* except participating-org)
   }
};


declare function iati-t:next-step($steps,$activity as element(iati-activity) ) as element (iati-activity)? {
   if (empty($steps)) then $activity 
   else
      let $step := $steps[1]
      let $new-activity := 
          typeswitch($step)
            case element(xslt) return 
               let $xslt := doc($step)
               return 
                   transform:transform($activity,$xslt,())
             case element (xquery) return
              let $module-load :=  if (exists($step/@location))
              then util:import-module($step/@uri, $step/@prefix, $step/@location)
              else ()  (: step is in the current library :)
              let $result := util:catch("*",
                              util:eval($step),
                              let $log := iati-t:log($activity,$step) return $activity
                             )
              return $result
           default return 
               $activity
       return iati-t:next-step(subsequence($steps,2),$new-activity)

};

declare function iati-t:run-steps($pipeline as element(pipeline), $activity as element(iati-activity)) {
   iati-t:next-step($pipeline/*,$activity)
};

declare function iati-t:log ($activity,$step){

 update insert 
    element error {
       attribute dateTime {util:system-dateTime()},
       $step,
       $activity/iati-identifier      
    }   
    into $iati-t:errors
};