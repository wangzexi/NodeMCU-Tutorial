# NodeMCU之旅（三）：响应配置按钮

## 引言
在之前的代码中，要连接的WIFI信息都已写死在代码里，这显然不能适应我们的需求。所以需要想个办法让用户可以配置这些信息。

## WIFI工作模式

NodeMCU支持STATION，SOFTAP，STATIONAP，NULLMODE四种模式。
> 设置WIFI模式
> [wifi.setmode()](http://nodemcu.readthedocs.io/en/master/en/modules/wifi/#wifisetmode)
>
> * `wifi.STATION` 当设备需要连接到WIFI路由器时使用。常在访问Internet时使用。
> * `wifi.SOFTAP` 当设备需要作为热点时使用。在此模式下你的设备会创建一个本地局域网，并出现在WIFI列表。在默认情况下，NodeMCU在本地局域网地址为192.168.4.1，其他设备将被分配为下一个的可用IP，比如192.168.4.2。
> * `wifi.STATIONAP` 同时应用以上两者。在此模式下你可以在创建一个热点的同时连接到其他WIFI路由器。
> * `wifi.NULLMODE` 关闭WIFI。

所以可以添加一个按钮，当按钮按下时，转换模式为`WIFI.STATIONAP`，然后通过手机接入NodeMCU的热点，进入设置页面配置WIFI信息。就像配置路由器一样。

## 接线

![wiring.jpg](wiring.jpg)

* 绿色的LED就是未来被远程控制的那颗，正极连接D1。

* 黄色的LED用于显示当前的WIFI工作模式，正极连接D2。

* 白色的按钮连接D3。

* 负极连接GND。

接线完成后，定义这些引脚：

```lua
IO_LED = 1
IO_LED_AP = 2
IO_BTN_CFG = 3

gpio.mode(IO_LED, gpio.OUTPUT)
gpio.mode(IO_LED_AP, gpio.OUTPUT)
gpio.mode(IO_BTN_CFG, gpio.INT)
```

注意，`IO_BTN_CFG`被设置为了`gpio.INT`模式，也就是中断模式。

## 响应按钮

通过`gpio.trig()`设置响应中断的回调函数。

> 设置响应中断的回调函数
> [gpio.trig()](http://nodemcu.readthedocs.io/en/master/en/modules/gpio/#gpiotrig)

响应按钮抬起时的事件：

```lua
function onBtnEvent()
	print('up~')
end
gpio.trig(IO_BTN_CFG, 'up', onBtnEvent)
```

上传代码。测试按下按钮，发现输出正常。

但存在一个问题：有时只按了一次，输出却不止一次。因为按钮的信号会有抖动。

这里提供一种去抖方法：

```lua
TMR_BTN = 6

function onBtnEvent()
	gpio.trig(IO_BTN_CFG)
	tmr.alarm(TMR_BTN, 500, tmr.ALARM_SINGLE, function()
		gpio.trig(IO_BTN_CFG, 'up', onBtnEvent)
	end)

	print('up~')
end
gpio.trig(IO_BTN_CFG, 'up', onBtnEvent)
```

 思路是，在首次触发之后，清除按钮的回调函数，在0.5秒后，恢复回调。

## 开始与结束配置

正如之前所讲，平常运行时WIFI模式为`wifi.STATION`，当按下按钮后，WIFI模式转为`wifi.STATIONAP`，再次按下后恢复`wifi.STATION`。

```lua
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
```

注意，`gpio.write(IO_LED_AP, gpio.LOW)`在函数外部，目的是在NodeMCU开机时，重置AP信号灯为熄灭状态。

之后，修改上节按钮事件函数里的`print('up~')`为：

```lua
switchCfg()
```

这样就可以通过按钮来控制AP的开启关闭了。

## 配置热点信息

在`print('Setting up WIFI...')`后添加下行代码，来配置热点名为 **'mymcu'** ，安全性为**开放**。

```lua
wifi.ap.config({ ssid = 'mymcu', auth = AUTH_OPEN })
```
关于`wifi.ap.config()`的更多细节，请参阅：

>配置热点信息
>[wifi.ap.config()](http://nodemcu.readthedocs.io/en/master/en/modules/wifi/#wifiapconfig)

最后，删去之前写死在代码里的WIFI连接配置`wifi.sta.config('MY_SSID', 'MY_PASSWORD')`。

因为随后，我们将提供操作界面，让用户自己来设置它们。