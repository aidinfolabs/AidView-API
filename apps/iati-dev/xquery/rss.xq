import module namespace rss = "http://tools.aidinfolabs.org/api/rss" at "../lib/rss.xqm";
import module namespace config = "http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";
import module namespace ui = "http://kitwallace.me/ui" at "/db/lib/ui.xqm";

declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";


let $query := iati-rss:query()
return 
if ($query/activity)
then
   iati-rss:activity($query)
else 
if ($query/mode="feeds")
then 
   let $serialize := util:declare-option("exist:serialize","method=text media-type=text/text")
   let $feeds := iati-rss:csv-feeds() 
   let $table := iati-rss:table-to-csv($feeds)
   return $table
else if ($query/country or $query/sector)
then 
   iati-rss:feed($query)
else 
   let $serialize := util:declare-option("exist:serialize","method=xhtml media-type=text/html")
   return
     <html>
      <head>
        <title>AidInfo Data feeds</title>
        <link rel="stylesheet" type="text/css" href="../assets/screen-2.css"/>

      </head>
      <body>
         <h1>AidInfo IATI Data Feeds</h1>
         {if ($query/mode="feeds-html")
          then
            let $serialize := util:declare-option("exist:serialize","method=xhtml media-type=text/html")
            let $feeds := iati-rss:csv-feeds() 
            return $feeds     
          else
       <div>
         <h2>Links</h2>
         <ul>
           <li><a href="?mode=feeds">All RSS feeds as CSV</a></li>
           <li><a href="?mode=feeds-html">All RSS feeds as HTML</a></li>       
         </ul>
         <h2>API</h2>
         <ul>
           <li>mode :  rss (default) , feeds  (CSV list of feeds), feeds-html (HTML list of feeds)</li>
           <li>
           <ul>EITHER 
              <li>country :  <a href="http://data.aidinfolabs.org/?type=code&amp;id=Country">ISO Alpha-2 codes</a></li> 
              OR
              <li>sector : 3 digit <a href="http://data.aidinfolabs.org/?type=code&amp;id=SectorCategory">DAC sector category codes</a> </li>
           </ul>
           </li>
           <li> age : age of extracted IATI activities in days based the activity's last-modified-date in the database - default  {$iati-rss:age}</li>
         </ul>
         <h2>RSS feed</h2>
         <p>The RSS feed items contain </p>
         <ul>
         <li>iati-identifier</li>  
         <li>title</li>
         <li>description</li>
         <li>link to the activity itself, currently in iatiexplorer</li>
         </ul>
         <h2>Issues</h2>
         
         <ul>
           
           <li>Descriptions - Word-specific codes have been included in the original XML files.  These are corrected in the feeds but need to be replaced when the document is stored in the database instead.</li>
           <li>Country code list - Country names are currently in uppercase and some names are corrupted. </li>
           <li>Sector (Category) names are extracted for  and these are a mixture of upper and lower case. </li>
           <li>Activities are included on the basis of the age of the activity's last-modified-date in the database. The relevance of the date needs to be reviewed.</li>
         </ul>
        </div>
        }
      </body>
    </html>