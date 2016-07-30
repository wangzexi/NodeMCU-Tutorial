print('Setting up WIFI...')
wifi.setmode(wifi.STATION)
wifi.sta.config('MY_SSID', 'MY_PASSWORD')
wifi.sta.connect()

tmr.alarm(1, 1000, tmr.ALARM_AUTO, function()
	if wifi.sta.getip() == nil then
		print('Waiting for IP ...')
		else
		print('IP is ' .. wifi.sta.getip())
	tmr.stop(1)
	end
end)