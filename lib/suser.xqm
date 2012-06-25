module namespace suser = "http://kitwallace.me/blogin";

declare function suser:login-form() {
 <div>
   <form method="?">
     <input type="hidden" name="mode" value="login"/>
     User <input name="email" size="30"/>
     <input type="submit" value="Login"/>
   </form>
 </div>
};

declare function suser:login($users) {
  let $email := request:get-parameter("email",())
  let $user := $users[email=$email]
  return
    if (exists($user))
    then 
       let $session := session:set-attribute("user",$user/id)
       return request:redirect-to(xs:anyURI(concat(request:get-url(),"?mode=home")))
    else 
       suser:login-form()
};

declare function suser:logout() {
  let $invalidate := session:invalidate()
  return
     request:redirect-to(xs:anyURI(concat(request:get-url(),"?mode=home")))
};

