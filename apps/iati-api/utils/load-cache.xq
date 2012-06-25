declare option exist:serialize "method=xhtml media-type=text/html";

let $cache-queries := 
<queries>
 <query>corpus=fullB&amp;groupby=Country&amp;result=values</query>
 <query>corpus=fullB&amp;groupby=Funder&amp;result=values</query>
 <query>corpus=fullB&amp;groupby=Sector&amp;result=values</query>
 <query>corpus=fullB&amp;groupby=SectorCategory&amp;result=values</query>
 <query>corpus=fullB&amp;groupby=Region&amp;result=values</query>
</queries>
return 
<ul>
{
for $query in $cache-queries/query
return 
   <li><a href="../xquery/woapi-c.xq?{$query}">{$query/string()}</a></li>
}

</ul>
