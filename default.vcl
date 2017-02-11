vcl 4.0;

import directors;
import std;
# Default backend definition. Set this to point to your content server.

# define our first nginx server

backend webServer1
{
	.host ="0.0.0.0";       #your web server IP Address
	.port="80";

	.probe = {
	        .url = "/";
	       	.timeout = 1s;
 	      	.interval = 6s;
	        .window = 5;
	        .threshold = 3;
  	 }
	
    .connect_timeout = 30s;
    .first_byte_timeout = 30s;
    .between_bytes_timeout = 30s;
}

backend webServer2
{
	.host ="0.0.0.0";        #your web server IP Address
	.port="80";

	.probe = {
	        .url = "/";
	       	.timeout = 1s;
 	      	.interval = 6s;
	        .window = 5;
	        .threshold = 3;
  	 }
	
    .connect_timeout = 30s;
    .first_byte_timeout = 30s;
    .between_bytes_timeout = 30s;
}

sub vcl_init {
    new app = directors.round_robin();        # For load balancing using Round Robin
	  app.add_backend(webServer1);
    app.add_backend(webServer2);
}


sub vcl_recv 
{
  set req.backend_hint = app.backend();

    # Ban bots coming.
	
    if (req.http.user-agent ~ "applebot|baiduspider|bingbot|googlebot|sogou|slurp|yandexbot") {
      return (synth(403, "Access Denied"));
    }   
	
  # optional - if user types admin section, this will be redirected to https because varnish supports http only.
  
  if (req.url ~ "^/admin" && req.http.X-Forwarded-Proto !~ "(?i)https")
  {
	set req.http.x-redir = "https://" + req.http.host + req.url;
    return (synth(750, "")); 
  }
  
  # Optional -  Do not cache these paths.
  
  if (req.url ~ "^/status\.php$" ||
      req.url ~ "^/update\.php" ||
      req.url ~ "^/admin" ||
      req.url ~ "^/admin/.*$" ||
      req.url ~ "^.*/ajax/.*$") {

    return (pass);
  }
  
 # Optional -  handling Cookies.
    
  if (req.url ~ "(?i)\.(pdf|asc|dat|txt|doc|xls|ppt|tgz|csv|png|gif|jpeg|jpg|ico|swf|css|js)(\?.*)?$") {
    unset req.http.Cookie;
  }
  
  if (req.http.Cookie) 
  {
    set req.http.Cookie = ";" + req.http.Cookie;
    set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
    set req.http.Cookie = regsuball(req.http.Cookie, ";(SESS[a-z0-9]+|SSESS[a-z0-9]+|NO_CACHE)=", "; \1=");
    set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");

    if (req.http.Cookie == "") 
	{
      	unset req.http.Cookie;
   	}
    else 
	{
     	 return (pass);
    	}
  }
}

sub vcl_synth {
  # Listen to 750 status from vcl_recv.
  if (resp.status == 750) 
  {
    // Redirect to HTTPS with 301 status.
    set resp.status = 301;
    set resp.http.Location = req.http.x-redir;
    return(deliver);
  }
}
