-------------
-- define
-------------
IO_LED = 1
IO_LED_AP = 2
IO_BTN_CFG = 3
IO_BLINK = 4

TMR_WIFI = 4
TMR_BLINK = 5
TMR_BTN = 6

gpio.mode(IO_LED, gpio.OUTPUT)
gpio.mode(IO_LED_AP, gpio.OUTPUT)
gpio.mode(IO_BTN_CFG, gpio.INT)
gpio.mode(IO_BLINK, gpio.OUTPUT)

-------------
-- button
-------------
function onBtnEvent()
	gpio.trig(IO_BTN_CFG)
	tmr.alarm(TMR_BTN, 500, tmr.ALARM_SINGLE, function()
		gpio.trig(IO_BTN_CFG, 'up', onBtnEvent)
	end)

	switchCfg()
end
gpio.trig(IO_BTN_CFG, 'up', onBtnEvent)

gpio.write(IO_LED_AP, gpio.LOW)

function switchCfg()
	if wifi.getmode() == wifi.STATION then
		wifi.setmode(wifi.STATIONAP)
		httpServer:listen(80)
		gpio.write(IO_LED_AP, gpio.HIGH)
	else
		wifi.setmode(wifi.STATION)
		httpServer:close()
		gpio.write(IO_LED_AP, gpio.LOW)
	end
end

-------------
-- blink
-------------
blink = nil
tmr.register(TMR_BLINK, 100, tmr.ALARM_AUTO, function()
	gpio.write(IO_BLINK, blink.i % 2)
	tmr.interval(TMR_BLINK, blink[blink.i + 1])
	blink.i = (blink.i + 1) % #blink
end)

function blinking(param)
	if type(param) == 'table' then
		blink = param
		blink.i = 0
		tmr.interval(TMR_BLINK, 1)
		running, _ = tmr.state(TMR_BLINK)
		if running ~= true then
			tmr.start(TMR_BLINK)
		end
	else
		tmr.stop(TMR_BLINK)
		gpio.write(IO_BLINK, param or gpio.LOW)
	end
end

-------------
-- wifi
-------------
print('Setting up WIFI...')
wifi.sta.config('MY_SSID', 'MY_PASSWORD')
wifi.ap.config({ ssid = 'mymcu', auth = AUTH_OPEN })
wifi.setmode(wifi.STATION)
wifi.sta.autoconnect(1)

status = nil

wifi.sta.eventMonReg(wifi.STA_WRONGPWD, function()
	blinking({100, 100 , 100, 500})
	status = 'STA_WRONGPWD'
	print(status)
end)

wifi.sta.eventMonReg(wifi.STA_APNOTFOUND, function()
	blinking({2000, 2000})
	status = 'STA_APNOTFOUND'
	print(status)
end)

wifi.sta.eventMonReg(wifi.STA_CONNECTING, function(previous_State)
	blinking({300, 300})
	status = 'STA_CONNECTING'
	print(status)
end)

wifi.sta.eventMonReg(wifi.STA_GOTIP, function()
	blinking()
	status = 'STA_GOTIP'
	print(status, wifi.sta.getip())
end)

wifi.sta.eventMonStart(1000)

-------------
-- http
-------------
dofile('httpServer.lua')

httpServer:use('/config', function(req, res)
	if req.query.ssid ~= nil and req.query.pwd ~= nil then
		wifi.sta.config(req.query.ssid, req.query.pwd)

		status = 'STA_CONNECTING'
		tmr.alarm(TMR_WIFI, 1000, tmr.ALARM_AUTO, function()
			if status ~= 'STA_CONNECTING' then
				res:type('application/json')
				res:send('{"status":"' .. status .. '"}')
				tmr.stop(TMR_WIFI)
			end
		end)
	end
end)

httpServer:use('/scanap', function(req, res)
	wifi.sta.getap(function(table)
		local aptable = {}
		for ssid,v in pairs(table) do
			local authmode, rssi, bssid, channel = string.match(v, "([^,]+),([^,]+),([^,]+),([^,]+)")
			aptable[ssid] = {
				authmode = authmode,
				rssi = rssi,
				bssid = bssid,
				channel = channel
			}
		end
		res:type('application/json')
		res:send(cjson.encode(aptable))
	end)
end)