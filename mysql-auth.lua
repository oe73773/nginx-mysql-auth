-- Get configuration from nginx configuration 
local db_username = ngx.var.mysql_db_username
local db_password = ngx.var.mysql_db_password
local db_host = ngx.var.mysql_db_host
local db_port = ngx.var.mysql_db_port
local db_name = ngx.var.mysql_db_name
local realm = ngx.var.my_realm
local stmt = ngx.var.my_stmt

-- shared dict for mysql user/password cache
local mysqlcache = ngx.shared.mysqlcache

-- Password check function
-- parameters:
--   pwhash: hashed password from mysql
--   password: decoded password from authorization header
-- return:
--   true  -> password matched
--   false -> password didn't match or no supported hash 
function checkpw(pwhash, password)
    local matchedPW = false
    ngx.log(ngx.NOTICE, string.format("pwhash: %s", pwhash))
    if string.find(pwhash, '^%$argon2i%$') or string.find(pwhash, '^%$argon2d%$')  or string.find(pwhash, '^%$argon2id%$') then
        local argon2 = require "argon2"
        ngx.log(ngx.NOTICE, string.format("Got a argon2 password"))
        local ok, err = argon2.verify(pwhash, password)
        if ok then
            matchedPW = true
        end
    elseif string.find(pwhash, "^%$2%$") or string.find(pwhash, "^%$2a%$") or string.find(pwhash, "^%$2y%$") then
        local bcrypt = require "bcrypt"
        ngx.log(ngx.NOTICE, string.format("Got a bcrypt password"))
        if bcyrpt.verify(password, pwhash) then
            matchedPW = true
        end
    elseif pwhash == ngx.md5(passord) then
        ngx.log(ngx.ERR, string.format("Got a md5 password"))
        matchedPW = true
    end 
    return matchedPW
end

-- function send 401 with basic auth realm to browser
function authentication_prompt()
    ngx.header.www_authenticate = string.format('Basic realm="%s"', realm)
    ngx.exit(401)
end

-- function do authentication
-- parameters:
--   user: remote user
--   password: decoded password from authorization header
-- no return value
-- call authentication_prompt if authentication failed
function authenticate(user, password)
    
    local loggedIn = false
    local pwhash

    if mysqlcache then
        pwhash = mysqlcache:get(user)
        if pwhash then
            ngx.log(ngx.NOTICE, string.format("Got user %s from cache", user))
            if checkpw(pwhash, password) then
                ngx.log(ngx.NOTICE, string.format("Login user %s with cached data", user))
                loggedIn = true
            end
        end
    end

    if not loggedIn then
        local mysql = require "luasql.mysql"

        local env = mysql.mysql()
        local conn = env:connect(db_name,db_username,db_password,db_host,db_port)

        if not conn then
            ngx.log(ngx.ERR, "Failed to create mysql object")
            ngx.exit(503)
        end

        stmt = string.format(stmt, user)
        local cur = conn:execute(stmt)

        local row = cur:fetch({}, "a")

        if row then
            local pwhash = string.format("%s", row.passwd)
            if checkpw(pwhash, password) then
                mysqlcache:set(user, pwhash, 3600)
                mysqlcache:flush_expired()
                ngx.log(ngx.NOTICE, string.format("Added %s to cache",user))
                loggedIn = true
            end
        end
    end

    if not loggedIn then
	ngx.log(ngx.ERR, string.format("Invalid login for %s",user))
        authentication_prompt()
    end
end

 
-- Get password from authorization header 
local remote_password
if ngx.var.http_authorization then
    local tmp = ngx.var.http_authorization
    tmp = tmp:sub(tmp:find(' ')+1)
    tmp = ngx.decode_base64(tmp)
    remote_password = tmp:sub(tmp:find(':')+1)
end

-- If remote user and remote passwort is set call authenticate function 
-- if not call authentication_prompt function  
if ngx.var.remote_user and remote_password then
    authenticate(ngx.var.remote_user, remote_password)
else
    authentication_prompt()
end

