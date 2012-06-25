module namespace pipeline = "http://tools.aidinfolabs.org/api/pipeline" ;
import module namespace config ="http://tools.aidinfolabs.org/api/config" at "config.xqm";
import module namespace codes ="http://tools.aidinfolabs.org/api/codes" at "codes.xqm";
declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";


declare variable $pipeline:conversion-rates := doc(concat($config:base,"currency/currency-conversion.xml"))/conversions/conversion;
declare variable $pipeline:qmonths := (1,1,1,2,2,2,3,3,3,4,4,4);
declare variable $pipeline:errors := doc(concat($config:data ,"pipeline-errors.xml"))/errors;

declare function pipeline:add-default-sector-vocab($activity as element(iati-activity)) as element(iati-activity) {
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


declare function pipeline:add-project-value($activity as element(iati-activity)) as element(iati-activity) {
let $value := 
 max( 
(for $type in ("C","D","E","IR","LR","R","IF","PD","TB")
return sum($activity/*/value[@iati-ad:transaction-type=$type]/@iati-ad:USD-value[. > 0])
)
 )
return
   element iati-activity {
      $activity/@*,
      if ($activity/activity-status/@code = ("3","4"))   (: bit of a fudge putting this here but it saves another pass :)
      then ()
      else attribute iati-ad:include {"include"},
      attribute iati-ad:project-value {$value},
      $activity/*
    }
};

declare function pipeline:convert-to-USD($nodes ,$default-currency) {
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
             let $transaction := $node/..
             let $date := if ($node/@iso-date and $node/@iso-date ne "")   (: this because of empty date strings everywhere :)
                         then $node/@isodate
                         else if ($node/@value-date and $node/@value-date ne "")
                         then $node/@value-date
                         else if ($transaction/transaction-date/@iso-date and $transaction/transaction-date/@iso-date ne "")
                         then $transaction/transaction-date/@iso-date
                         else ($transaction/period-start/@iso-date,$transaction/period-end/@iso-date,"2011-01-01")[1]
                         
            let $transaction-date :=( $transaction/transaction-date/@iso-date,$transaction/period-start/@iso-date,$transaction/period-end/@iso-date,$date)[1]
            let $transaction-type := 
                  typeswitch ($transaction) 
                     case element(transaction) return ($transaction/transaction-type/@code,$transaction/activity-type/@code)[1]  (:for hewlett :)
                     case element(budget) return "TB"
                     case element(planned-disbursement) return "PD"
                     default return ()
            let $dp := tokenize($date,"-")
            let $year := $dp[1]
            let $USD-value :=  
             if ($value-currency eq "USD")
             then $node/text()
             else pipeline:convert-value-to-USD($value-currency, $year ,$node)
            return
            element value {
               $node/@* ,
               if ($value-currency) then attribute iati-ad:currency {$value-currency} else (),
               attribute iati-ad:date {$date}, 
               attribute iati-ad:transaction-date {$transaction-date},
               attribute iati-ad:transaction-type {$transaction-type}, 
               if ($USD-value) then attribute iati-ad:USD-value {$USD-value} else (),
               $node/node()
            }
         default return 
            element {node-name($node)} {
               $node/@*,
               pipeline:convert-to-USD($node/node(),$default-currency)
            }
};

declare function pipeline:convert-to-USD($activity as element(iati-activity)) as element(iati-activity) {
let $default-currency := ($activity/@default-currency,"USD")[1]
return 
    pipeline:convert-to-USD($activity,$default-currency)
};

(: conversion rate table contains rates of conversion from USD to the target currency 
   
:)
declare function pipeline:convert-value-to-USD($from-code, $year, $amount) {
let $year := if ($year > '2010') then '2010' else $year
let $rate-from := $pipeline:conversion-rates[@to-currency = $from-code][@year=$year][@from-currency = "USD"]/@rate
let $conv-amount :=  round(xs:double($amount) div xs:double($rate-from))
return
   ($conv-amount,0)[1]
};


declare function pipeline:add-DEC-3-sectors($activity as element(iati-activity)) as element(iati-activity) {
   element iati-activity {
      $activity/@*,

       for $code in distinct-values(
                  for $sector in $activity/sector[@vocabulary="DAC"]/@code
                  return codes:code-value("Sector",$sector)/category
                  )
       let $category := codes:code-value("SectorCategory",$code)
       let $percentage := sum($activity/sector[@vocabulary="DAC"][codes:code-value("Sector",@code)/category = $code]/(@percentage,100)[1])
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
declare function pipeline:add-project-value($activity as element(iati-activity)) as element(iati-activity) {
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

declare function pipeline:add-wo-locations($activity as element(iati-activity)) as element(iati-activity) {
let $locations := collection($config:base,"geo")//iati-activity[iati-identifier = $activity/iati-identifier]/location
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

declare function pipeline:apportion-sector-value($activity as element(iati-activity) ) as element (iati-activity)? {
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

declare function pipeline:apportion-country-value($activity as element(iati-activity) ) as element (iati-activity)? {
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

declare function pipeline:apportion-region-value($activity as element(iati-activity) ) as element (iati-activity)? {
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

declare function pipeline:add-org-key($activity as element(iati-activity) ) as element (iati-activity)? {
    element iati-activity {
       $activity/@*,
       for $org in $activity/participating-org
       return 
             element participating-org {
                 $org/@*,
                 if ($org/@ref ne "") then attribute iati-ad:org {$org/@ref} else (),
                 if ($org/@ref ne "" and $org/@role=("Funding","funding")) then attribute iati-ad:funder {$org/@ref} else (),
                 $org/node()
             },
        if (empty($activity/participating-org[@role=("Funding","funding")]) and exists ($activity/reporting-org))
        then
            let $org := $activity/reporting-org
            return 
               element participating-org {
                 attribute role {"Funding"},
                 attribute ref {$org/@ref},
                 attribute type {$org/@type},
                 attribute iati-ad:org {$org/@ref},
                 attribute iati-ad:funder {$org/@ref},
                 $org/node()
             }
        else (),
        
        $activity/(* except participating-org)
   }
};


declare function pipeline:next-step($steps,$activity as element(iati-activity) ) as element (iati-activity)? {
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
                              let $log := pipeline:log($activity,$step) return $activity
                             )
              return $result
           default return 
               $activity
       return pipeline:next-step(subsequence($steps,2),$new-activity)

};

declare function pipeline:run-steps($pipeline as element(pipeline), $activity as element(iati-activity)) {
   pipeline:next-step($pipeline/*,$activity)
};

declare function pipeline:log ($activity,$step){

 update insert 
    element error {
       attribute dateTime {util:system-dateTime()},
       $step,
       $activity/iati-identifier      
    }   
    into $pipeline:errors
};