print("Get available APs")
wifi.setmode(wifi.STATION) 
wifi.sta.getap(function(t)
   available_aps = "" 
   if t then 
      for k,v in pairs(t) do 
         ap = string.format("%-10s",k) 
         ap = trim(ap)
         available_aps = available_aps .. "<option value='".. ap .."'>".. ap .."</option>"
      end 
      setup_server(available_aps)
   end
end) 

local unescape = function (s)
   s = string.gsub(s, "+", " ")
   s = string.gsub(s, "%%(%x%x)", function (h)
         return string.char(tonumber(h, 16))
      end)
   return s
end


function regen_conten(aps)
    file.remove('content.txt')
    file.open("content.txt", "w")
    file.writeline('<div class="card">')
    file.writeline('<div class="main-logo icon-flower"></div>')
    file.writeline('<h1>Inguru</h1>')
    file.writeline('<h2>Smart GreenHouse by Datumatik</h2>')
    file.writeline('<br>')
    file.writeline('<br>')
    file.writeline('<span>The device is has no internet access. Please connect to a wifi signal to allow Weather Station be accessible on your network.</span>')
    file.writeline('<form method="get" action="/" onsubmit="submitEvent()">')
    file.writeline('<div class="section-logo icon-internet"></div>')
    file.writeline('<h3>Internet Access Wi-Fi Network</h3>')
    file.writeline('<span class="input-icon icon-wifi-scan"></span><select name="ap">'.. aps .. '</select><br>')
    file.writeline('<span class="input-icon icon-password"></span><input type="pasword" name="psw" placeholder="Password"><br>')
    file.writeline('<div class="checkbox"><input type="checkbox" name="offline">Enable <i>offline</i> mode</div>')
    file.writeline('<div class="section-logo icon-signal"></div>')
    file.writeline('<h3>Private Access Wi-Fi Signal</h3>')
    file.writeline('<span class="input-icon icon-pencil"></span><input placeholder="ESP8266_PRIVATE" name="privname" minlength="1"><br>')
    file.writeline('<span class="input-icon icon-password"></span><input placeholder="Password (>= 8)" name="privpwd" minlength="8"><br>')
    file.writeline('<button type="submit">Save</button>')
    file.writeline('</form>')
    file.writeline('</div>')
    collectgarbage();
end


function send_file(clientconn, filename)
   print("--stop 1")
   print("Serving..."..filename)
 
   if file.list()[filename] then
       print("--stop 2")
       local continue = true
       --local size = file.list()[filename]
       local bytesSent = 0
       -- Chunks larger than 1024 don't work.
       -- https://github.com/nodemcu/nodemcu-firmware/issues/1075
       local chunkSize = 1024
       while continue do
          collectgarbage()
    
          -- NodeMCU file API lets you open 1 file at a time.
          -- So we need to open, seek, close each time in order
          -- to support multiple simultaneous clients.
          file.open(filename, "r")
          file.seek("set", bytesSent)
          local chunk = file.read(chunkSize)
          file.close()
    
          clientconn:send(chunk)
          bytesSent = bytesSent + #chunk
          print("Sent: " .. bytesSent .. " of " .. bytesSent)
          if (string.len(chunk) < chunkSize) then continue = false end
          chunk = nil
       end
   else
       print("File "..filename.." not found")
       client:send("HTTP/1.1 404 Not Found\r\n\n")
   end
end


function setup_server(aps)
   print("Setting up Wifi AP")
   wifi.setmode(wifi.SOFTAP)

   regen_conten(aps)

   local str=wifi.ap.getmac();
   local ssidTemp=string.format("%s%s%s",string.sub(str,10,11),string.sub(str,13,14),string.sub(str,16,17));

   local cfg = {}
   cfg.ssid = "ESP8266_"..ssidTemp.."_CONFIGURE"
   wifi.ap.config(cfg)      
   wifi.ap.setip({ip="192.168.66.1",netmask="255.255.255.0",gateway="192.168.66.1"})
   print("Setting up webserver")

   local httpRequest={}
   httpRequest["/"]="min_page.html";
   httpRequest["/index.html"]="min_page.html";
   httpRequest["/index.html"]="min_page.html";
   httpRequest["/index.php"]="min_page.html";
   httpRequest["/content"]="content.txt";
    
   local getContentType={};
   getContentType["/"]="text/html";
   getContentType["/index.html"]="text/html";
   getContentType["/content"]="text/plain";
   local filePos=0;

   if srv then srv:close() srv=nil end
    srv=net.createServer(net.TCP)
    srv:listen(80,function(conn)
        conn:on("receive", function(conn,request)
            print("[New Request]");
            local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP");
            if(method == nil)then
             _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP");
            end
            local _GET = {}
            if (vars ~= nil)then
               for k, v in string.gmatch(vars, "(%w+)=([^%&]+)&*") do
               --for k, v in string.gmatch(vars, "([\w]+)=([^%&]+)&*") do
                   _GET[k] = unescape(v)
               end
            end
              
            if (_GET.psw ~= nil and _GET.ap ~= nil and _GET.privname ~= nil and _GET.privpwd ~= nil) then
              
              if(string.len(_GET.privpwd) >= 8 ) then
                print("Saving data..")
                file.open("config.lua", "w")
                file.writeline('ssid = "' .. _GET.ap .. '"')
                file.writeline('password = "' .. _GET.psw .. '"')

                
                file.writeline('ap_ssid = "' .. _GET.privname .. '"')
                file.writeline('ap_psw = "' .. _GET.privpwd .. '"')
                file.close()
                
                node.compile("config.lua")
                file.remove("config.lua")
                file.remove('content.txt')

                print("Rebooting....")
                
                conn:close();
                node.restart()
              end
            end
           
            if getContentType[path] then
                requestFile=httpRequest[path];
                print("[Sending file "..requestFile.."]");            
                filePos=0;
                conn:send("HTTP/1.1 200 OK\r\nContent-Type: "..getContentType[path].."\r\n\r\n");            
            else
                print("[File "..path.." not found]");
                conn:send("HTTP/1.1 404 Not Found\r\n\r\n")
                conn:close();
                collectgarbage();
            end
        end)
        conn:on("sent",function(conn)
            if requestFile then
                if file.open(requestFile,'r') then
                    file.seek("set",filePos);
                    local partial_data=file.read(1024);
                    file.close();
                    if partial_data then
                        filePos=filePos+#partial_data;
                        print("["..filePos.." bytes sent]");
                        conn:send(partial_data);
                        if (string.len(partial_data)==1024) then
                            return;
                        end
                       
                    end
                else
                    print("[Error opening file "..requestFile.."]");
                end
            end
            print("[Connection closed]");
            conn:close();
            collectgarbage();
        end)
    end)
   print("Please connect to: " .. wifi.ap.getip())
end

function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end
