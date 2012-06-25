module namespace activity-transform = "http://tools.aidinfolabs.org/api/activity-transform";
import module namespace codes ="http://tools.aidinfolabs.org/api/codes" at "../lib/codes.xqm";
import module namespace config ="http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";
import module namespace wfn= "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";

declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";
declare variable $activity-transform:qmonths := (1,1,1,2,2,2,3,3,3,4,4,4);
declare variable $activity-transform:errors := doc(concat($config:data ,"pipeline-errors.xml"))/errors;
declare variable $activity-transform:locations := collection($config:base,"geo")/*/iati-activity;

declare function activity-transform:add-default-sector-vocab($activity as element(iati-activity)) as element(iati-activity) {
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


declare function activity-transform:add-project-value($activity as element(iati-activity)) as element(iati-activity) {
let $value := 
 max( 
(for $type in ("C","D","E","IR","LR","R","IF","PD","TB")
return sum($activity/*/value[@iati-ad:transaction-type=$type]/@iati-ad:USD-value[. > 0])
)
 )
return
   element iati-activity {
      $activity/@*,
      attribute iati-ad:project-value {$value},
      $activity/*
    }
};

declare function activity-transform:convert-to-USD($nodes ,$default-currency) {
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
             else activity-transform:convert-value-to-USD($value-currency, $year ,$node)
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
               activity-transform:convert-to-USD($node/node(),$default-currency)
            }
};

declare function activity-transform:convert-to-USD($activity as element(iati-activity)) as element(iati-activity) {
let $default-currency := ($activity/@default-currency,"USD")[1]
return 
    activity-transform:convert-to-USD($activity,$default-currency)
};

(: conversion rate table contains rates of conversion from USD to the target currency 
   
:)
declare function activity-transform:convert-value-to-USD($from-code as xs:string, $year as xs:string, $amount as xs:double) {
let $year := if ($year > '2010') then '2010' else $year
let $rate-from := doc(concat($config:config,"currency/currency-conversion2.xml"))/*/conversion[to-currency = $from-code][year = $year]/rate 
let $conv-amount :=  round(xs:double($amount) div xs:double($rate-from))
return
   ($conv-amount,0)[1] 
};


declare function activity-transform:add-DAC-3-sectors($activity as element(iati-activity)) as element(iati-activity) {
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
declare function activity-transform:add-project-value($activity as element(iati-activity)) as element(iati-activity) {
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

declare function activity-transform:add-wo-locations($activity as element(iati-activity)) as element(iati-activity) {
let $locations := collection(concat($config:base,"geo"))/*/iati-activity[iati-identifier = $activity/iati-identifier]/location
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

declare function activity-transform:apportion-sector-value($activity as element(iati-activity) ) as element (iati-activity)? {
 let $value := number($activity/@iati-ad:project-value)
 return
   element iati-activity {
       $activity/@*,
       for $vocabulary in distinct-values($activity/sector/@vocabulary)
       let $sectors := $activity/sector[@vocabulary=$vocabulary]
       let $count := count($sectors)
       return 
          for $sector in $sectors
          let $percentage := if ($sector/@percentage castable as xs:integer) then xs:integer($sector/@percentage) else round(100 div $count) 
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

declare function activity-transform:apportion-country-value($activity as element(iati-activity) ) as element (iati-activity)? {
 let $value := number($activity/@iati-ad:project-value)
 let $count := count($activity/recipient-country)
 return
   element iati-activity {
       $activity/@*,

       for $country in $activity/recipient-country
       return 
             element recipient-country {
                 $country/@*,
                 if (codes:code-value("Country",$country/@code))
                 then attribute iati-ad:country {$country/@code}
                 else (),
                 attribute iati-ad:project-value {if ($country/@percentage castable as xs:integer) then round($value * $country/@percentage div 100)  else $value div $count},
                 $country/node()
             },
        $activity/(* except recipient-country)
   }
};

declare function activity-transform:apportion-region-value($activity as element(iati-activity) ) as element (iati-activity)? {
 let $value := number($activity/@iati-ad:project-value)
 let $count := count($activity/recipient-region)
 return
   element iati-activity {
       $activity/@*,
       for $region in $activity/recipient-region
       return 
             element recipient-region {
                 $region/@*,
                 if (codes:code-value("Region",$region/@code))
                 then attribute iati-ad:region {$region/@code}
                 else (),
                 attribute iati-ad:project-value {if ($region/@percentage castable as xs:integer) then round($value * $region/@percentage div 100)  else $value div $count},
                 $region/node()
             },
        $activity/(* except recipient-region)
   }
};

declare function activity-transform:add-org-key($activity as element(iati-activity) ) as element (iati-activity)? {
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

declare function activity-transform:clean-text($activity as element(iati-activity)) as element(iati-activity) {
   element iati-activity {
       $activity/@*,
       for $el in $activity/(title,description)
       return 
          element {name($el)} {
             $el/@*,
             wfn:clean-text($el/text())
          },
       $activity(* except (title,description))
   }
};

declare function activity-transform:check-aidview($activity as element(iati-activity)) as element(iati-activity) {
   element iati-activity {
      $activity/@*,
      if ($activity/activity-status/@code = ("3","4"))  
      then ()
      else attribute iati-ad:include {"aidview"},
      $activity/*
    }
};

 declare function activity-transform:transform($activity) {

 let $activity := activity-transform:add-default-sector-vocab($activity)
 let $activity := activity-transform:convert-to-USD($activity)
 let $activity := activity-transform:add-project-value($activity)
 let $activity := activity-transform:apportion-sector-value($activity)
 let $activity := activity-transform:add-DAC-3-sectors($activity)
 let $activity := activity-transform:apportion-country-value($activity)
 let $activity := activity-transform:apportion-region-value($activity)
 let $activity := activity-transform:add-org-key($activity)
 let $activity := activity-transform:add-wo-locations($activity)
(:  let $activity := activity-transform:clean-text($activity) :)
 let $activity := activity-transform:check-aidview($activity)
 return $activity
 };