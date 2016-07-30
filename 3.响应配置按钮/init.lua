-------------
-- define
-------------
IO_LED = 1
IO_LED_AP = 2
IO_BTN_CFG = 3
IO_BLINK = 4

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
		gpio.write(IO_LED_AP, gpio.HIGH)
	else
		wifi.setmode(wifi.STATION)
		gpio.write(IO_LED_AP, gpio.LOW)
	end
end

-------------
-- blinking
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
