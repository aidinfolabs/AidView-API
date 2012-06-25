module namespace band ="http://kitwallace.me/band";
(: functions to define the behaviour of a BandMap structure :) 
        
declare function  band:band-for($bandmap as element(),$v as xs:decimal ) { 
               ($bandmap/band[ $v >= xs:decimal(@min) ])[last()] 
}; 
        
declare function band:is-bandMap($bandmap as element()) as xs:boolean { 
        (: invariant for a  bandMap :)
        (: there are at least 2 band elements :) 
        count($bandmap/band) >= 2 and
        (:  all band elements have an attribute 'min' castable to xs:decimal :) 
        (every $band in $bandmap/band satisfies $band/@min castable as xs:decimal ) 
        and
        (: the band mins are strictly ascending :) 
        (every $i in (1 to count($bandmap/band) -1 ) satisfies
               (xs:decimal($bandmap/band[$i]/@min) <  xs:decimal($bandmap/band[xs:integer($i )+ 1]/@min))
         ) 
};
         
declare function band:safe-band-for($bandmap as element(), $v as item()) { 
        (: wrapper for band:band-for which  checks pre-conditions and post-conditions, 
            returning an error if a violation has occured 
        :)
        if ( band:is-bandMap($bandmap) 
              and $v castable as xs:decimal 
               and xs:decimal($v) >= xs:decimal( $bandmap/band[1]/@min)) 
         then
             let $band := band:band-for($bandmap,$v) 
             return 
                     if  ($band = $bandmap/band and xs:decimal($v) >= xs:decimal($band/@min) 
                         and (every  $higher in $bandmap/band[. is $band]/following-sibling::band 
                                    satisfies xs:decimal($v) < xs:decimal($higher/@min) ) 
                                    and (every $lower in $bandmap/band[. is  $band]/preceding-sibling::band 
                                    satisfies xs:decimal($v) >  xs:decimal($lower/@min) ) )
                     then $band 
                     else <error>Post-condition failed</error>
        else <error>Pre-condition failed</error>
}; 
       
  