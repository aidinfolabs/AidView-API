module namespace config = "http://tools.aidinfolabs.org/api/config" ;

declare variable $config:host :=  "http://datadev.aidinfolabs.org";
declare variable $config:ip := "109.104.101.243";
declare variable $config:base :=  "/db/apps/iati/";
declare variable $config:version := "2";
declare variable $config:last-modified:= "2012/05/21";
declare variable $config:data :=  concat($config:base,"data/");
declare variable $config:system :=  concat($config:base,"system/");
declare variable $config:logs :=  concat($config:base,"logs/");
declare variable $config:config := concat($config:base,"config/");
declare variable $config:olap := concat($config:base,"olap/");
declare variable $config:rss-age :="200";
declare variable $config:logging := false();
declare variable $config:ckan-base := "http://www.iatiregistry.org/";

declare variable $config:map := 
<terms>
   <term name="set">Activity Sets</term>    
   <term name="corpus">Corpuses</term>
   <term name="Host">Hosts</term>
   <term name="activity">Activities</term>
   <term name="facet">Facets</term>
</terms>;

declare function config:login() {
  xmldb:login($config:base,"aidview","oxford")
};
