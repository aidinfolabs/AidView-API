module namespace iati-b = "http://kitwallace.me/iati-b" ;

declare variable $iati-b:base :=  "/db/apps/iati-api/";
declare variable $iati-b:data :=  concat($iati-b:base,"data/");
declare variable $iati-b:system :=  concat($iati-b:base,"system/");
declare variable $iati-b:logs :=  concat($iati-b:base,"logs/");
declare variable $iati-b:paths := doc(concat($iati-b:system,"paths.xml"))/paths;
declare function iati-b:path-at($code as xs:string) as element(path) {
   $iati-b:paths/path[@code]
};
