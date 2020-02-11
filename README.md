# nginx-mysql-auth

Use nginx access_by_lua_file in order to use a mysql table or view as password file.
A lua_shared_dict is used as cache for user and passwords.

In my case I wanted to use Owncloud/Nextcloud Users to allow access on private Ant Media Server LiveApp behind a nginx as authenticating proxy. 

The password in Database must be a argon2 or bcrypt hash. MD5 hashes are supported but it is not recomended to use MD5 because of known weakness.

argon2 and bcrypt requieres installation of modules via luarocks

```bash
$ luarocks install argon2
$ luarocks install argon2
```

All required configuration must be set in ngnix configuration.

## Set lua_shared_dict (is required)

A mysqlcache lua_shared_dict must be defined in http config section. NGINX Documentation https://github.com/openresty/lua-nginx-module#ngxshareddict .

```nginx
http {
     lua_shared_dict mysqlcache 1m;
     server {
         location /set {
            ...
         }
     }
}
```

In this example 1MB shared memory is alocated. Please use a size according to your need. 

## Setup db connection (is required)

Following variables are used to setup the database connection:
* mysql_db_username    _User name for DB Login_
* mysql_db_password    _Passwort for DB Login_
* mysql_db_host        _FQDN of DB Host_
* mysql_db_port        _TCP Port of DB_
* mysql_db_name        _Database to connect_
* my_stmt              _Select statement to get password hash form db. use %q as placeholder for login username_

This can be set in Server or Location section

```nginx
server {
   set $mysql_db_username "dbuser";
   set $mysql_db_password "dbpassword";
   set $mysql_db_host "sample.host.fqdn";
   set $mysql_db_port "3306";
   set $mysql_db_name "htpasswd";
   set $my_stmt "SELECT passwd FROM htusers WHERE uid = lower (%q)";
   ...
}
```
or
```nginx
server {
   location /video {
      set $mysql_db_username "dbuser";
      set $mysql_db_password "dbpassword";
      set $mysql_db_host "sample.host.fqdn";
      set $mysql_db_port "3306";
      set $mysql_db_name "htpasswd";
      set $my_stmt "SELECT passwd FROM htusers WHERE uid = lower (%q)";
      ...
   }
   ...
}
```   

## Setup realm name (is required)

The my_realm var is used to show a custom realm name in Browser Login Dialog.  
e.G.:
```
https://member.mgw4u.de is requesting your username and password. The site says: “MYSQL Login”
```
This can be set in Server or Location section

```nginx
server {
   set $my_realm "MYSQL Login";
   ...
}
```
or
```nginx
server {
   location /video {
      set $my_realm "MYSQL Login";
      ...
   }
   ...
}
```   

## Set access_by_lua_file (is required)

last but not least set access_by_lua_file

```nginx
server {
   location /video {
      set $my_realm "MYSQL Login";
      ...
      access_by_lua_file '/etc/nginx/mysql-auth.lua';
      ...
   }
   ...
}
```   

