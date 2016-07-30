# NodeMCU之旅（二）：断线自动重连，闪烁连接状态

## 事件监听器

NodeMCU采用了事件响应的方式。也就是说，只需为事件设置一个回调函数，当事件发生时，回调函数就会被调用。

> 注册事件监听器
> [wif.sta.eventMonReg()](http://nodemcu.readthedocs.io/en/master/en/modules/wifi/#wifistaeventmonreg)
>
> 开始监听
> [wifi.sta.eventMonStart()](http://nodemcu.readthedocs.io/en/master/en/modules/wifi/#wifistaeventmonstart)

### 通过监听器获知wifi连接状态

```lua
-- init.lua
print('Setting up WIFI...')
wifi.setmode(wifi.STATION)
wifi.sta.config('MY_SSID', 'MY_PASSWORD')
wifi.sta.connect()

status = nil

wifi.sta.eventMonReg(wifi.STA_GOTIP, function()
	status = 'STA_GOTIP'
	print(status, wifi.sta.getip())
end)

wifi.sta.eventMonStart(1000)
```

`wifi.sta.eventMonStart(1000)`函数表明检测网络状态的间隔是一秒。

不止如此，常用的监听器还有：

```lua
wifi.sta.eventMonReg(wifi.STA_WRONGPWD, function()
	status = 'STA_WRONGPWD'
	print(status)
end)

wifi.sta.eventMonReg(wifi.STA_APNOTFOUND, function()
	status = 'STA_APNOTFOUND'
	print(status)
end)

wifi.sta.eventMonReg(wifi.STA_CONNECTING, function(previous_State)
	status = 'STA_CONNECTING'
	print(status)
end)
```

## 断线自动重连

有时因为路由器重启等原因，NodeMCU可能会掉线，好在NodeMCU可以设置自动连接：

> 自动连接
> [wifi.sta.autoconnect()](http://nodemcu.readthedocs.io/en/master/en/modules/wifi/#wifistaautoconnect)

替换上节代码中的`wifi.sta.connect()`为


```lua
wifi.sta.autoconnect(1)
```

这样，当配置的wifi有效时，NodeMCU便能自动连入。

## 控制LED闪烁

在NodeMCU上有一个LED可用。可以用它来显示当前的连接状态。经测试，控制该LED的引脚为D4。

这是一个控制LED以特定延迟序列闪烁的函数。

```lua
IO_BLINK = 4
TMR_BLINK = 5

gpio.mode(IO_LED_BLINK, gpio.OUTPUT)

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
```

`blinking()`函数需要传入一个数组，数组元素依次表示LED亮灭的延迟。例子：

```lua
blinking({300, 300}) -- 循环闪烁：亮300ms，灭300ms
blinking({100, 100 , 100, 500}) -- 循环闪烁：亮100ms，灭100ms，亮100ms，灭500ms

blinking() -- 常亮
blinking(gpio.LOW) -- 常亮
blinking(gpio.HIGH) -- 常灭
```

## 闪烁显示连接状态

现在就可以结合监听器用LED显示连接状态了。

在上一节的监听器事件里，各添加一行闪烁的即可。

```lua
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
```

