ssid = "MySSID"
password  = "12345678"

ap_ssid = "ESP8266_PRIVATE"
ap_psw  = "adminadmin"
timeout=0

if pcall(function () 
   dofile("config.lc")
end) then
   print("Connecting to WIFI...")
   realtype = wifi.sleeptype(wifi.MODEM_SLEEP)
   wifi.setmode(wifi.STATIONAP);
   
   local cfg={};

   cfg={}
   cfg.ssid=ap_ssid;
   cfg.pwd=ap_psw;
   wifi.ap.config(cfg);
   
   cfg={};
   cfg.ip="192.168.66.1";
   cfg.netmask="255.255.255.0";
   cfg.gateway="192.168.66.1";
   wifi.ap.setip(cfg);
         
   wifi.sta.config(ssid,password)
   wifi.sta.connect()

   tmr.alarm(1, 1000, 1, function() 
      if wifi.sta.getip() == nil then        
         print("IP unavaiable, waiting... " .. timeout) 
      timeout = timeout + 1
      if timeout >= 60 then
       file.remove('config.lc')
       node.restart()
      end
      else 
         tmr.stop(1)
         print("Connected, IP is "..wifi.sta.getip())
         dofile("run_program.lua")
      end 
   end)
else
   print("Enter configuration mode")
   dofile("run_config.lua")
end
