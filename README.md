# nat_detect

## 一、简介
基于构建可信网络，某些企业内部可能需要发现内网NAT主机，并对主机进行抑制。本工具旨在不改变现网拓扑结构，对设备新能消耗小，不需要额外的设备投入即可实现对内网共享上网的探测。

## 二、原理
目前已知的 ~~（可能）~~ 存在的探测方法如下：
* 基于 IPv4 数据包包头内的 TTL 字段的检测
* 基于 HTTP 数据包请求头内的 User-Agent 字段的检测
* DPI (Deep Packet Inspection) 深度包检测技术
* 基于 IPv4 数据包包头内的 Identification 字段的检测
* 基于网络协议栈时钟偏移的检测技术
* Flash Cookie 检测技术
  
下面我会对这些技术的实现原理作出进一步说明

### 1、基于 IPv4 数据包包头内的 TTL 字段的检测 **（本工具使用该方法）**

>存活时间（Time To Live，TTL），指一个数据包在经过一个路由器时，可传递的最长距离（跃点数）。 每当数据包经过一个路由器时，其存活次数就会被减一。当其存活次数为0时，路由器便会取消该数据包转发，IP网络的话，会向原数据包的发出者发送一个ICMP TTL数据包以告知跃点数超限。其设计目的是防止数据包因不正确的路由表等原因造成的无限循环而无法送达及耗尽网络资源。

这是一个比较有效且合理的检测技术，IPv4数据包下存在 TTL（Time To Live）这一字段，数据包每经过一个路由器（即经过一个网段），该TTL值就会减一。

不同的操作系统的默认 TTL 值是不同的，Windows 是 128， macOS/iOS、Linux/Android 是 64。

因此如果接入路由器（NAT主机），我们的通过路由器的数据包会变为 127 或 63，一旦检测到这种数据包TTL不是128或64，即可判定为用户接入了路由器，存在共享上网。

* 优点： 
  * 检测迅速，资源消耗小
* 缺点：
  * PC上虚拟机采用NAT联网可能误判
  * TTL值可通过Privoxy修改而被固定，无法被检测

### 2、基于 HTTP 数据包请求头内的 User-Agent 字段的检测 
HTTP数据包请求头存在一个叫做 User-Agent 的字段，该字段通常能够标识出操作系统类型，例如：
```text
Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.72 Safari/537.36 Edg/89.0.774.45

Mozilla/5.0 (iPad; U; CPU OS 3_2_1 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Mobile/7B405
```
通过多次抓包检测此字段，若发现同时出现例如Windows NT 10.0 iPad 的字段，则判定存在多设备上网。

### 3、DPI (Deep Packet Inspection) 深度包检测技术
这个检测方案比较先进，检测系统会抓包分析应用层的流量，根据不同应用程序的数据包的特征值来判断出是否存在多设备上网。

具体可参考：[基于dpi技术的网络共享设备检测方法及系统](https://patents.google.com/patent/CN106411644A/zh)

此种方式已确认在锐捷反代理相关设备上应用，由于此项功能极耗费性能，不推荐使用，但准确率较高。

### 4、基于 IPv4 数据包包头内的 Identification 字段的检测
IPv4数据包包头存在一个叫做 Identification 的字段，该字段通常能够标识出数据包的唯一性，在实际的应用中通常把它当做一个计数器，一台主机依次发送的IP数据包内的 Identification 字段会对应的依次递增，同一时间段内，而不同设备的 Identification 字段的递增区间一般是不同的，因此可以根据一段时间内递增区间的不同判断出是否存在多设备共享上网。

具体可以参考此专利：[基于IPid和概率统计模型的nat主机个数检测方法](https://patents.google.com/patent/CN104836700A/zh)

不过经过抓包分析，Windows 7 的TCP/IP协议栈对 Identification 字段的实现是递增，而 iOS 的实现是保持全0，但Windows 10+及Andioid 8+对IPid已经不是简单的递增，其发出的混合数据流本身是乱序的，因此此法是否可行有待商榷。

### 5、基于网络协议栈时钟偏移的检测技术
不同主机物理时钟偏移不同，网络协议栈时钟与物理时钟存在对应关系，不同主机发送报文频率与时钟存在统计对应关系，通过特定的频谱分析算法，发现不同的网络时钟偏移来确定不同主机。

具体可以参考此专利：[一种基于时钟偏移的加密流量共享检测方法与装置](https://patents.google.com/patent/CN111970173A/zh)

目前大多数设备均会通过NTP对时间进行同步，该方法有效性未知。

### 6、Flash Cookie 检测技术
这个技术已经用不到了，Flash都凉了。不过还是提一下。

Flash Cookie会记录用户在访问 Flash 网页的时候保留的信息，只要当用户打开浏览器去上网，那么就能被设备记录到 Flash Cookie 的特征值，由于 Flash Cookie 不容易被清除，而且具有针对每个用户具有唯一，并且支持跨浏览器，所以被用于做防共享检测。

具体参考：[深信服防共享测试指导书](https://bbs.sangfor.com.cn/plugin.php?id=sangfor_databases:index&mod=viewdatabase&tid=6273)

## 三、用法
首先需在网络中三层交换机上配置`sflow`，锐捷设备可参考：[sflow配置](https://search.ruijie.com.cn:3014/api/anno/short/url/QjYvUba)的sflow部分配置，将sFlow Collector地址配置为内网服务器地址（端口使用缺省6343），sFlow Agent地址为交换机IP地址。其他品牌交换机类似，具体请翻阅相关文档。

服务器防火墙需提前打开6343/UDP端口，具体方法不再赘述。

```bash
git clone https://github.com/zyh001/nat_detect.git
cd nat_detect
sudo chmod +x ./goflow ./gojq ./nat-detect.sh
sudo ./nat-detect.sh -f 10.100.0.0/16,10.101.0.0/16 -n 5
    [WARNING] screen is installed, skip
    [INFO] 开始采集数据！
    [INFO] 循环圈数: 5
    [INFO] 开始进行第1次计算
    [INFO] 开始进行第2次计算
    [INFO] 开始进行第3次计算
    [INFO] 开始进行第4次计算
    [INFO] 开始进行第5次计算
    [INFO] 存在用户IP："10.100.0.24", MAC："b0:25:aa:40:d7:70"共享上网！权重: 24
    [INFO] 存在用户IP："10.100.0.100", MAC："00:e0:4c:84:7c:f8"共享上网！权重: 2
    [INFO] 存在用户IP："10.101.1.164", MAC："58:69:6c:ec:c5:25"共享上网！权重: 1

## 参数详解
## -f 为需过滤内网的IP段，多IP段用逗号分隔，根据情况可设置为有线或无线地址段。默认为所有内网网段。
## -n 为循环圈数，表示需对数据进行采样的次数，默认采样5次。
## -t 为每次采样时间，表示单次对数据采样时间，单位秒，默认为10。
## 权重值越高，表示用户存在共享上网的置信越高。
```

## 四、引用的其它项目
* [https://github.com/itchyny/gojq](https://github.com/itchyny/gojq)    用于对json进行分析
* [https://github.com/netsampler/goflow2](https://github.com/netsampler/goflow2)    用于采集交换机发送的sflow数据