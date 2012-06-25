import module namespace config = "http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";  
import module namespace admin = "http://tools.aidinfolabs.org/api/admin" at "../lib/admin.xqm";

(: run after loading the code code and configuration files and the initialdata collections :)
let $login := config:login()
return admin:initialize()

