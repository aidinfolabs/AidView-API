(:~ 
    :   This module defines a set of functions to manipulate Mercator and LatLong coordinates.
    :   Copyright (c)  2009 Chris Wallace   chris.wallace@uwe.ac.uk,  kit.wallace@gmail.com
    :   This program is free software; you can redistribute it and/or
    :    modify it under the terms of the GNU Lesser General Public License
    :   as published by the Free Software Foundation; either version 2
    :   of the License, or (at your option) any later version.
    :
    :   This program is distributed in the hope that it will be useful,
    :    but  WITHOUT ANY WARRANTY; without even the implied warranty of
    :    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    :    GNU Lesser General Public License for more details.
    :    For a  copy of the GNU Lesser General Public License
    :    write to the Free Software  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
    :
    :   Conversion formulae come  from the <a
    :             href="http://www.ordnancesurvey.co.uk/oswebsite/gps/information/coordinatesystemsinfo/guidecontents/index.html"
    :            > Ordnance Survey guide </a>to coordinate transformations.
    :            
    :   The module uses a number of data types  which are defined in geoTypes.xsd:
    :    Mercator positions are represented by elements  such as 
    :            &lt;geo:Mercator easting="358994" northing="173480"/>  
    :
    :    LatLong positions are represented by elements such as 
    :           &lt;geo:LatLong latitude="51.45880171387952" longitude="-2.591599694709258"/>
    :
    :    Elliposids are represented by elements such as :
    :          &lt;geo:Ellipsoid a='6377563.396' b='6356256.910'  />;    
    : 
    :     Transverse Meridian Projections :
    :         &lt;geo:Projection F0='0.9996012717'  lat0='49'   long0='-2'   E0='400000' N0='-100000'/>
    :
    :    Helmert Transformations :
    :     &lt;geo:HelmertTransformation x="446.448" y="-125.157" z="542.060" rx="7.281901490265231E-7" ry="0.0000011974897923405538" rz="0.000004082616008623402" s="0.9999795106"/>
    :
    :  @author Chris Wallace, UWE Bristol
    :  @version 1.1
    :  @since April 15, 2009
    :  @since April 15, 2009  - height added to coordinates 
    :  @since October 17, 2009 - added OS-to-Grid and supporting decode table NationalGrid.xml
    :  @since Decemeber 5, 2010 - added grid to OS 
    :  @see  http://www.cems.uwe.ac.uk/xmlwiki/geo/geoTypes.xsd   
    :  @see http://exist-db.org  
    :  @see  http://www.ordnancesurvey.co.uk/oswebsite/gps/information/coordinatesystemsinfo/guidecontents/index.htm;;Ordnance Survey Guide

:)

module namespace geo="http://kitwallace.me/geo";

declare namespace math="http://exist-db.org/xquery/math";

declare variable $geo:Airy1830 := <geo:Ellipsoid a='6377563.396' b='6356256.910'  />; 	
declare variable $geo:WGS84 := <geo:Ellipsoid a='6378137.00' b='6356752.3141'/>;
declare variable $geo:UKOS :=  <geo:Projection F0='0.9996012717'  lat0='49'   long0='-2'   E0='400000' N0='-100000'/>;
declare variable $geo:NationalGrid := doc("/db/apps/lib/NationalGrid.xml")/Grid;

(:  --------- utility functions - sb in more generic module --------------------------- :)
declare function geo:lz ($n as xs:string?) as xs:integer {
  xs:integer(concat (string-pad("0",2 - string-length($n)),$n))
};

declare function geo:round($n,$decimals) {
   round-half-to-even($n,$decimals)
};

(: ----------------------------- format conversions ---------------------------------- :)

(:~
    : @param $s  - input string in the format of      DD-MMH, DD-MH, DD-MM-SH,* DD-MM-SSH 
    :  where H is NSE or W
    : @return decimal degrees
:)
declare function geo:dms-to-decimal($s as xs:string) as xs:decimal {
  let $hemi := substring($s,string-length($s),1)
  let $rest :=  substring($s,1, string-length($s)-1)
  let $f := tokenize($rest,"-")
  let $deg := geo:lz($f[1])
  let $min:= geo:lz($f[2])
  let $sec := geo:lz($f[3])
  let $dec :=$deg +  ($min + $sec div 60) div 60
  let $dec := round-half-to-even($dec,6)
  return 
     if ($hemi = ("S","W"))
     then - $dec
     else $dec
};

(:~
  : e.g.  55' 15.1"N ,
  :  5' 06.4"W

:)
declare function geo:dm-to-decimal($s as xs:string ) as xs:decimal? {

    let $s := replace($s,"[^0-9|N|S|E|W|\.]"," ")
    let $f := tokenize(normalize-space($s),"\s")
    let $deg := xs:integer($f[1])
    let $min := xs:decimal($f[2])
    let $hemi := $f[3]
    let $dec := $deg + $min div 60
    let $dec := round-half-to-even($dec,6)
     return 
        if ($hemi = ("S","W"))
        then - $dec
        else $dec
};

(:~
  : e.g.  55' 15.1"N ,
  :    5' 06.4"W

:)
declare function geo:dms-to-decimal($s as xs:string ) as xs:decimal? {
    let $s := replace($s,"[^0-9|N|S|E|W|\.]"," ")
    let $f := tokenize(normalize-space($s),"\s")
    let $deg := xs:integer($f[1])
    let $min := xs:integer($f[2])
    let $sec := xs:decimal($f[3])
    let $hemi := $f[4]
    let $dec := $deg + $min div 60 + $sec div 3600
    let $dec := round-half-to-even($dec,6)
     return 
        if ($hemi = ("S","W"))
        then - $dec
        else $dec
};

(:~
    :  convert from degrees, minutes and decimal seconds to decimal degrees
    :  @param $d  signed degrees
    :  @param $m  minutes
    :  @param $s  decimal seconds
    :  @return decimal degrees
~:)
declare function geo:dms-as-decimal($d,$m as xs:integer,$s as xs:double)  as xs:double {
   ( if ($d > 0) then 1 else -1)  * (($s  div 60 + $m ) div 60 + abs($d))
};


(:~
   :   Convert from decimal degrees to a string formated as degrees, minutes and seconds 
   :    Absolute value of degrees is used since the function is to be used  
   :   @param  $dms   decimal Degrees
   :   @return   absolute degrees, minutes and seconds in a string with standrad anotation
~:)

declare function geo:decimal-as-dms($dms as xs:double)  as xs:string {
let $dms := math:abs($dms)
   let $deg := math:floor($dms)
   let $min := math:floor(($dms - $deg) * 60)
   let $sec := ($dms - $deg - $min div  60) * 3600
   return concat($deg, "&#176; ", $min, "&#8242; ",$sec,"&#8243; ")
};

(:~
   : Convert seconds to degrees in radians 
   :  @param $seconds   decimal seconds
   :  @return    decimal decgrees in radians
~:)
declare function geo:seconds-as-radians($seconds as xs:double) as xs:double {
   math:radians($seconds) div 3600
};

(:~
   : Format a LatLong with N/S E/W
   :  @param $ll  LatLong element
   :  @return  formated string with decimal latitude and longitude
~:)
declare function geo:LatLong-as-string($ll as element(geo:LatLong))  as xs:string {    
       concat ( if ($ll/@latitude > 0) then concat ( $ll/@latitude, 'N ') else concat (0  - $ll/@latitude,'S '),                     
                if ($ll/@longitude > 0 ) then concat ( $ll/@longitude, 'E ') else concat ( 0 - $ll/@longitude , 'W ')
              )
};

(:~
   : Format a LatLong with N/S E/W
   :  @param $ll  LatLong element
   :  @return  formated string with degrees, minutes and seconds latitude and longitude
~:)
declare function geo:LatLong-as-dmsstring($ll as element(geo:LatLong))  as xs:string {    
     concat ( if ($ll/@latitude > 0) then concat (geo:decimal-as-dms( $ll/@latitude), 'N ') else concat (geo:decimal-as-dms(0  - $ll/@latitude),'S '),                     
              if ($ll/@longitude > 0 ) then concat ( geo:decimal-as-dms($ll/@longitude), 'E ') else concat (geo:decimal-as-dms( 0 - $ll/@longitude) , 'W ')
                     )
};

(:~  
    :  Round a LatLong element  to a given number of digits after the decimal point
    :  @param  $ll     LatLong element
    :  @param decimals  Number of decimal digits
    :   @return  rounded LatLong element
~:)
declare function geo:round-LatLong($ll as element(geo:LatLong) ,$decimals as xs:integer)  as element(geo:LatLong) {

element geo:LatLong {
     attribute latitude {round-half-to-even($ll/@latitude,$decimals)},
     attribute longitude {round-half-to-even($ll/@longitude,$decimals)},
     if ($ll/@height and $ll/@height != 0) then attribute height {round-half-to-even($ll/@height,$decimals)} else ()
    }
};


(:~  
    : Round a Mercator element  to a given number of digits after the decimal point
    :  @param  $en     Mercator element
    :  @param decimals  Number of decimal digits
   :   @return  rounded Mercator element
~:)
declare function geo:round-Mercator($en as element(geo:Mercator) ,$decimals as xs:integer) as element(geo:Mercator) {
element geo:Mercator {
     attribute easting {round-half-to-even($en/@easting,$decimals)},
     attribute northing {round-half-to-even($en/@northing,$decimals)},
     if ($en/@height and $en/@height != 0) then attribute height {round-half-to-even($en/@height,$decimals)} else ()
    }
};

(:~
     : convert an all numeric OS coordinate to UK National Grid coordinates to a specified resolution
     :  e.g. geo:OS2grid(216524,771283,5) = "NN1652471283",
     : @param $easting  UK ordnance survey easting 
     : @param $northing UK ordnance survey northing
     : @param $n  number of digits in gridref
     : @return National grid reference in the form : mapprefix easting northing 
     
~:)
declare function geo:OS-to-Grid($easting  as xs:string, $northing as xs:string, $n as xs:integer) {
     let $es := string($easting)
     let $ns := string($northing)
     let $ep := if (string-length($es) =7) then substring($es,1,2) else if (string-length($es) = 6) then substring($es,1,1) else "0"
     let $en := if (string-length($es) =7 ) then substring($es,3,$n) else if (string-length($es) = 6) then substring($es,2,$n) else  substring($es,1,$n)

     let $np := if (string-length($ns) =7) then substring($ns,1,2) else if (string-length($ns) = 6) then substring($ns,1,1) else "0"
     let $nn := if (string-length($ns) =7) then substring($ns,3,$n) else if (string-length($ns) = 6) then substring($ns,2,$n) else  substring($ns,1,$n)
     let $prefix := $geo:NationalGrid/square[@x=$ep][@y=$np]/@prefix
     return concat($prefix,$en,$nn)
};

(:~ convert an UK grid coordinate to easting and northing  
   : eg.   geo:grid-to-OS("NN1652471283") = (216524,771283)
    :  Lower precsion OS
   :@param $OSG 
   :@return (northing, easting)
:)

declare function geo:Grid-to-OS($OSG as xs:string)  as element(geo:Mercator) {
   let $OSG := normalize-space($OSG)
   let $prefix := substring($OSG,1,2)
   let $ne := substring($OSG,3)
   let $square := $geo:NationalGrid/square[@prefix=$prefix]
   let $precision := string-length($ne) div 2
   let $easting := xs:integer(concat($square/@x,substring($ne,1,$precision),string-pad("0",5 - $precision)))
   let $northing := xs:integer(concat($square/@y,substring($ne,$precision+1),string-pad("0",5 - $precision)))
   return 
      geo:Mercator ($easting,$northing)
};

(: ------------------------------ Constructors ------------------------------------------------------- :)
(:~
    :  Construct a LatLong element 
    :  @param $latitude        The Latitude in decimal degrees
    :  @param $longitude    The Longitude in decimal degrees 
    :  @return                          LatLong element
~:)

declare function geo:LatLong($latitude, $longitude as xs:double ) as element(geo:LatLong) {
element geo:LatLong {
          attribute latitude { $latitude},  
          attribute longitude { $longitude }
       }
};

(:~
    :  Construct a LatLong element  with height 
    :  @param $latitude        The Latitude in decimal degrees
    :  @param $longitude    The Longitude in decimal degrees 
    :  @param $height         The height in metres
    :  @return                          LatLong element
~:)
declare function geo:LatLong($latitude, $longitude ,$height as xs:double ) as element(geo:LatLong) {
element geo:LatLong {
          attribute latitude { $latitude},  
          attribute longitude { $longitude },
          attribute height { $height}
       }
};

(:~
    :  Construct a Mercator element
    :  @param $easting  Easting
    :  @param $northing Northing
    :  @return                     Mercator element
~:)
declare function geo:Mercator($easting,$northing as xs:double) as element(geo:Mercator) {
 element geo:Mercator {
       attribute easting {$easting},
       attribute northing {$northing}
     }
};

(:~
    :  Construct a Mercator element
    :  @param $easting  Easting
    :  @param $northing Northing
    :  @return  Mercator element
~:)
declare function geo:Mercator($easting,$northing,$height as xs:double) as element(geo:Mercator) {
 element geo:Mercator {
       attribute easting {$easting},
       attribute northing {$northing},
       attribute height {$height}
     }
};

(:~
    :  Construct the Helmert Transformation to correct Airy1830 XYZ to GWS84 XYZ coordinates.
    :  This constructor is needed because the function calls are not allowed in a variable definition
    :  @return  Helmert 97 values Transformation  to correct Airy1830 XYZ to GWS84 XYZ coordinates.
~:)
declare function geo:Airy1830-to-WGS84 () {
  <geo:HelmertTransformation 
        x="446.448" y="-125.157" z="542.060" 
        rx="{geo:seconds-as-radians(0.1502)}" ry="{geo:seconds-as-radians(0.2470)}" rz="{geo:seconds-as-radians(0.8421) }"  
        s="{1  - 20.4894 * 0.000001}"
   /> 
};


(: -------------------   Geometry functions -------------- :)
(:~  
    : Compute the eccentricity squared for an ellipsoid
    :  The value may have been memoized in the ellipsoid using geo:add-eccentricity 
    :   Memoization may be beneficial when a large number of conversions are required but needs testing
    :  @param  $e    Ellipsoid
   :   @return eccentricity squared
~:)
declare function geo:eccentricity2( $e as element(geo:Ellipsoid) )  as xs:double {
 if ($e/@e2)   (:  if memoized :)
 then xs:double($e/@e2)
 else ($e/@a * $e/@a -$e/@b * $e/@b) div  ($e/@a* $e/@a)
};

(:~  
    :  Compute the value of nu for  ellipsoid/latitude
    :  @param  $e    Ellipsoid
    :  @parame $latitude   Latitude in decimal degress
    :  @return nu 
~:)
declare function geo:nu($e as element(geo:Ellipsoid) ,$latitude as xs:double )  {
   $e/@a div (math:sqrt(1 - (geo:eccentricity2($e) * (  math:power(math:sin($latitude),2)))))
};

(:~
    : return an Ellipsoid which extends the input Ellipsoid if it is not defined
    :   @param $e  Ellipsoid
    :   @return  Ellipsoid which includes the attribute e2 holding the eccentricity squared
~:)
declare function geo:add-eccentricity2($e as element(geo:Ellipsoid))   as element(geo:Ellipsoid) {
 element geo:Ellipsoid {
        $e/@*,
        if (empty($e/@e2))
        then attribute e2 {geo:eccentricity2($e)}
        else ()
   }
};

(:~
    :  Convert from a Transverse Mercator projection to a LatLong based on the supplied ellipsoid
    :   @param $en  Mercator element
    :   @param  $e   Ellipsoid
    :   @param  $p  Transverse Mercator projection
    :   @return   converted LatLong coordinates
~:)
declare function geo:Mercator-to-LatLong($en as element(geo:Mercator), $e as element(geo:Ellipsoid), $pr as element(geo:Projection))  as element(geo:LatLong) {
let  
    $a := $e/@a,  
    $b := $e/@b,
    $F0 := $pr/@F0, 
    $lat0 := math:radians($pr/@lat0), 
    $long0 :=math:radians($pr/@long0),  
    $N0 := $pr/@N0, 
    $E0 := $pr/@E0,                     
    $N := $en/@northing,
    $E := $en/@easting,
    $e2 := geo:eccentricity2($e),                          
    $n := ($a - $b) div ($a + $b), $n2 := $n*$n, $n3 := $n*$n*$n,
    $lat:= geo:meridonal-arc($lat0, $lat0,$N, 0, $a, $b, $n,$n2,$n3,$N0,$F0),
 
   $coslat := math:cos($lat),
   $sinlat := math:sin($lat), $sin2lat := $sinlat * $sinlat,
   $nu := $a*$F0 div math:sqrt(1 - $e2*$sin2lat),              
   $rho := $a*$F0*(1 - $e2) div math:power(1 - $e2*$sin2lat, 1.5),  
   $eta2 := $nu div $rho - 1,

   $tanlat := math:tan($lat),
   $tan2lat := $tanlat*$tanlat, $tan4lat := $tan2lat*$tan2lat, $tan6lat := $tan4lat*$tan2lat,
   $seclat := 1 div $coslat,
   $nu3 := $nu*$nu*$nu, $nu5 := $nu3*$nu*$nu, $nu7 := $nu5*$nu*$nu,
   $VII := $tanlat div (2*$rho*$nu),
   $VIII := $tanlat div (24*$rho*$nu3)*(5 + 3*$tan2lat + $eta2 - 9*$tan2lat*$eta2),
   $IX := $tanlat div (720*$rho*$nu5)*(61 + 90*$tan2lat + 45*$tan4lat),
   $X := $seclat div $nu,
   $XI := $seclat div (6*$nu3)*($nu div $rho + 2*$tan2lat),
   $XII := $seclat div (120*$nu5)*(5 + 28*$tan2lat + 24*$tan4lat),
   $XIIA :=$seclat div (5040*$nu7)*(61 + 662*$tan2lat + 1320*$tan4lat + 720*$tan6lat),

   $dE := ($E - $E0), $dE2 := $dE*$dE, $dE3 := $dE2*$dE, $dE4 := $dE2*$dE2, $dE5 := $dE3*$dE2, $dE6 := $dE4*$dE2, $dE7 := $dE5*$dE2,
   $lat := $lat - $VII*$dE2 + $VIII*$dE4 - $IX*$dE6,
   $long := $long0 + $X*$dE - $XI*$dE3 + $XII*$dE5 - $XIIA*$dE7

   return 
      geo:LatLong(math:degrees($lat),math:degrees($long))
};

(:~
    :  Compute Merdional arc  
    :  Private function
 ~:)
declare function geo:meridonal-arc($latn, $lat0, $N, $Mn,$a, $b, $n, $n2, $n3, $N0, $F0 as xs:double) as xs:double {
 let 
     $lat := ($N - $N0 - $Mn) div ($a*$F0) + $latn,
     $Ma := (1 + $n + (5 div 4)*$n2 + (5 div 4)*$n3) * ($lat - $lat0),
     $Mb := (3*$n + 3*$n*$n + (21 div 8)*$n3) * math:sin($lat - $lat0) * math:cos($lat + $lat0),
     $Mc := ((15 div 8)*$n2 + (15 div 8)*$n3) * math:sin(2*($lat - $lat0)) * math:cos(2*($lat+$lat0)),
     $Md := (35 div 24)*$n3 * math:sin(3*($lat - $lat0)) * math:cos(3*($lat + $lat0)),
     $M := $b * $F0 * ($Ma - $Mb + $Mc - $Md)             
 return 
   if ($N - $N0 - $M < 0.00001)
   then $lat
   else geo:meridonal-arc($lat, $lat0, $N, $M, $a, $b, $n, $n2, $n3, $N0, $F0 ) 
};

(:~
    :   Convert from an OS Mercator location based on Airy1830 to a LatLong 
    :   @param $en  Mercator element
    :   @return   converted LatLong coordinates
~:)
declare function geo:Mercator-to-LatLong($en as element(geo:Mercator))  as element(geo:LatLong) {
        geo:Mercator-to-LatLong($en,$geo:Airy1830,$geo:UKOS)
}; 

(:~
   :   Convert form a LatLong position on an Ellipsoid to a Transverse Mercator position using a Mercator Projection
   :  @param   $ll LatLong position
   :  @param   $e   Ellipsoid
   :  @param   $p   Projection
   :  @return    Mercator position
~:)
declare function geo:LatLong-to-Mercator($ll as element(geo:LatLong), $e as element(geo:Ellipsoid), $pr as element(geo:Projection))  as element(geo:Mercator) {
let 
    $a := $e/@a,  
    $b := $e/@b,
    $F0 := $pr/@F0, 
    $N0 := $pr/@N0, 
    $E0 := $pr/@E0,                     
    $lat0 := math:radians($pr/@lat0), 
    $long0 :=math:radians($pr/@long0),  
    $lat := math:radians($ll/@latitude),
    $long := math:radians($ll/@longitude),
    $sinlat := math:sin($lat), $sin2lat := $sinlat * $sinlat,
    $coslat := math:cos($lat), $cos2lat := $coslat * $coslat, $cos3lat := $cos2lat * $coslat ,  $cos5lat := $cos3lat * $cos2lat ,
    $tanlat := math:tan($lat), $tan2lat := $tanlat * $tanlat, $tan4lat := $tan2lat * $tan2lat,
    $latd := $lat - $lat0,  $lats := $lat + $lat0,
    $longd := $long - $long0, $longd2 := $longd * $longd, $longd3 := $longd2 * $longd, $longd4 := $longd3 * $longd, $longd5 := $longd4 * $longd, $longd6 := $longd5 * $longd,

    $e2 := geo:eccentricity2($e),                          
    $n := ($a - $b) div ($a + $b), $n2 := $n*$n, $n3 := $n2*$n,
    $nu := $a*$F0 div math:sqrt(1 - $e2*$sin2lat),  $nu2 := $nu * $nu,            
    $rho := $a*$F0*(1 - $e2) div math:power(1 - $e2*$sin2lat, 1.5),  
    $eta2 := $nu div $rho - 1,
    
    $M := $b * $F0 * (
                  (1 + $n + 1.25 * $n2 + 1.25 * $n3) * $latd 
               -  (3 * $n + 3 * $n2 + ( 21 div 8 ) * $n3) * math:sin($latd) * math:cos($lats)
              + ( (15 div 8) * ($n2 +$n3) * math:sin(2 * $latd) * math:cos(2 * $lats))
               - (35 div 24) * $n3 * math:sin(3 * $latd) * math:cos (3 * $lats)
               ),
     $I := $M + $N0,
    $II :=  $nu * $sinlat * $coslat div 2,
    $III := $nu * $sinlat * $cos3lat * ( 5 -  $tan2lat + 9 * $eta2 ) div 24,
    $IIIA := $nu * $sinlat * $cos5lat * (61 - 58 * $tan2lat + $tan4lat) div 720,
    $IV := $nu * $coslat,
    $V := $nu * $cos3lat * ($nu div $rho - $tan2lat) div 6,
    $VI := $nu  * $cos5lat * ( 5 - 18 * $tan2lat + $tan4lat + (14 * $eta2) - (58 * $tan2lat * $eta2)) div 120, 
    $N := $I + $II * $longd2 + $III * $longd4 + $IIIA * $longd6,
    $E := $E0 + $IV * $longd + $V * $longd3 + $VI * $longd5
 return 
   geo:Mercator($E,$N)
};

(:~
   :  Convert from a LatLong position based on WSG84 OS National Grid location 
   :  @param   $ll LatLong position
   :  @return    National Grid  position
~:)
declare function geo:LatLong-to-Mercator($ll as element(geo:LatLong)) as element(geo:Mercator) {
     geo:LatLong-to-Mercator($ll,$geo:Airy1830,$geo:UKOS)
}; 

(:~
    :  Convert  LatLong $lll  on the $e Ellipsoid  to  XYZ coordinates
    :  @param  $p  XYZ coordinates 
    :  @param $e   Ellipsoid
    :  @return   LatLong of $p on the $e Ellipsoid
~:)
declare function geo:LatLong-to-XYZ ($ll as element(geo:LatLong), $e  as element(geo:Ellipsoid)) as element(geo:XYZ) {
    let  $rlat :=math:radians($ll/@latitude)
    let  $rlong := math:radians( $ll/@longitude)
    let $height := ($ll/@height,0)[1]
    let  $nu := geo:nu($e,$rlat)
    return 
          <geo:XYZ
                x="{($nu + $height)  * math:cos($rlat) * math:cos($rlong)}" 
                y="{($nu + $height)  *  math:cos($rlat) * math:sin($rlong)}" 
                z="{($nu  * (1 - geo:eccentricity2($e)) +$height) * math:sin($rlat)}"
           />
};

(:~
    :   Apply a Helmert Transformation to an XYZ position
    :   @param  $p  initial XYZ coordinates
    :   @param  $t    Helmert Transformation
    :   @return  tranformed XYZ position
~:)
declare function geo:transform-XYZ ($p as element(geo:XYZ) ,$t  as element(geo:HelmertTransformation)) as element(geo:XYZ) {
  <geo:XYZ
         x="{        $p/@x * $t/@s           -    $p/@y * $t/@rz     +  $p/@z * $t/@ry     +    $t/@x }"
         y="{        $p/@x * $t/@rz          +   $p/@y * $t/@s      -   $p/@z * $t/@rx     +    $t/@y  }"
         z="{-1 * $p/@x * $t/@ry          +    $p/@y * $t/@rx     +  $p/@z *$t/@s       +    $t/@z }"
       />
};

(:~
    :  Convert an XYZ postion to a LatLong relative to an Ellipsoid
    :  @param  $p  XYZ coordinates 
    :  @param $e   Ellipsoid
    :  @return   LatLong of $p on the $e Ellipsoid
~:)
declare function geo:XYZ-to-LatLong($p  as element(geo:XYZ), $e as element(geo:Ellipsoid)) as element(geo:LatLong) {
 let $r := math:sqrt(math:power($p/@x,2) + math:power($p/@y,2))
 let $initialLat := math:atan2 ($p/@z , $r * (1 - geo:eccentricity2($e))  )
 let $lat := geo:iterate-XYZ-to-Lat($e, $initialLat, $p/@z, $r)
 let $long := math:atan2( $p/@y , $p/@x )
 let $height :=  $r div math:cos($lat) - geo:nu($e,$lat)
 return    
     geo:LatLong( math:degrees($lat),math:degrees($long), $height )
 };

(:~
    :  refine latitude 
    :  Private function
~:)
declare function geo:iterate-XYZ-to-Lat ($e as element(geo:Ellipsoid), $lat, $z , $r as xs:double) as xs:double {
    let $newLat := math:atan2($z + geo:eccentricity2($e) *  geo:nu($e,$lat) * math:sin($lat) ,$r )
    return 
        if (abs($lat - $newLat) > 0.000000001) 
        then geo:iterate-XYZ-to-Lat ($e, $newLat ,$z, $r)
        else $newLat
};

(:~
    :   Convert OS coordinates to  WSG84 LatLong 
    :   @param   $os   Ordnance Survey National Grid location
    :   @return    LatLong in WSG84
~:)
declare function geo:OS-to-LatLong($os as element(geo:Mercator))  as element(geo:LatLong) {
    let $e1 := $geo:Airy1830
    let $e2 := $geo:WGS84
    let $ll := geo:Mercator-to-LatLong($os,$e1, $geo:UKOS)
    let $xyz := geo:LatLong-to-XYZ($ll, $e1)
    let $newXYZ:= geo:transform-XYZ($xyz, geo:Airy1830-to-WGS84())
    return geo:XYZ-to-LatLong($newXYZ,$e2)
};


(: ----------------------------- distance functions -------------------------------- :)
(:~ 
   :  Compute distance between two latLongs using plain-sailing suitable for short distances  
   :  @param  $f   LatLong
   :  @param  $s  LatLong
   :  @return   distance in nautical miles 
~:)
declare function geo:plain-distance ($f, $s as element(geo:LatLong))  as xs:double {
   let $longCorr := math:cos(math:radians(($f/@latitude +$s/@latitude) div 2))
   let $dlat :=  ($f/@latitude - $s/@latitude) * 60
   let $dlong := ($f/@longitude - $s/@longitude) * 60 * $longCorr
   return math:sqrt(($dlat * $dlat) + ($dlong * $dlong))
};

(:~
     : Compute distance between twoLatLong positions using great circle calculation via the spherical law of cosines formula
     :  @param  $f   LatLong
     :  @param  $s  LatLong
     :  @return   distance in nautical miles 
~:)
declare function geo:great-circle-distance  ($f, $s as element(geo:LatLong))  {
   let 
       $flat := math:radians($f/@latitude),
       $slat := math:radians($s/@latitude),
       $dlong :=math:radians($f/@longitude) - math:radians($s/@longitude),
       $d := math:degrees(math:acos(math:sin($flat) * math:sin($slat) + math:cos($flat) * math:cos($slat) * math:cos ($dlong) ))
   return 
       $d *  60
};

