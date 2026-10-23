## 项目介绍

做SMC EA，难的不是写一个BOS、OB、FVG函数，而是把摆动高低点、结构突破、订单块、缺口、流动性、前周期高低点、加权评分、下单/平仓/风控串成一套能跑的闭环。

这份源码是按MQL5 EA框架编写的SMC策略，明文不加密，适合研究聪明钱逻辑、节省从零搭模块的时间，也方便二次开发。

<br>

### 核心内容

* MQL5 EA完整框架：OnInit / OnTick，新K线触发，CopyRates取200根已完成K线，CTrade下单，按magic + symbol管理持仓；

* 多周期结构：当前周期执行，H4聚合BOS/CHOCH投射回当前周期，叠加H4前高前低参与评分；

* SMC核心模块齐全：swing高低点、BOS/CHOCH、订单块OB、FVG、流动性扫掠、前周期高低点；

* 加权评分：前高前低、聚合BOS、BOS/CHOCH、OB回踩、FVG回踩、流动性扫掠分别计分；净分过entryThreshold出信号，strongThreshold强信号评分已预留；

* 结构止损止盈：支撑/阻力、TP1/TP2候选、ATR缓冲；固定点数SL/TP与结构位结合，并自动校验经纪商最小止损距离；

* 执行风控：最大点差过滤、保证金检查、手数按最小/最大/步长归一化、按信号方向平反向仓再开仓、按magic过滤持仓；

* 参数可改：手数、固定止损止盈点数、最大点差、各模块权重、阈值、swing长度、流动性范围等均为源码内变量，可自行修改。

<br>

### 使用提醒

* 默认单品种、当前图表运行；示例参数为EURUSD、1.10手、200点SL、400点TP、最大点差50，仅为源码默认，实盘前务必按品种、资金、经纪商规则调整；

* 先策略测试器回测，再模拟盘/小资金验证；SMC 策略概配置方案与源码默认参数不完全一致（如阈值0.45/0.70/0.008 vs 源码0.55/0.75/0.01），以源码为准，可按需统一；

* 源码为策略研究/二次开发用途，不含收益承诺；外汇/CFD杠杆风险较大。

<br>

### 适合人群

有MQL5基础，想研究SMC聪明钱逻辑、需要明文EA源码二次开发、希望省去BOS/OB/FVG/流动性模块搭建时间的人。

<br>

### 风险声明

1、本策略源码仅供学习与技术研究使用，不构成任何投资建议，请在法律法规允许的范围内使用本项目；
<br>
2、策略源码不是收益承诺，回测和历史表现不代表未来收益，如需在实盘中运行本策略，请慎重考虑；
<br>
3、虚拟商品，售出不退；拍前请确认具备MQL5 Python策略运行环境。

<br>
<br>

___如果您对程序有疑问，可以向我询问，谢谢！___

![加好友](https://private-user-images.githubusercontent.com/19700138/682741720-c01f82c6-f631-4e7f-9d65-1441768d3e6f.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3OTI3NjExMzIsIm5iZiI6MTc5Mjc2MDgzMiwicGF0aCI6Ii8xOTcwMDEzOC82ODI3NDE3MjAtYzAxZjgyYzYtZjYzMS00ZTdmLTlkNjUtMTQ0MTc2OGQzZTZmLnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNjEwMjMlMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjYxMDIzVDEzMDcxMlomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWM3NDc4MGYwNzU5MjJlYzkwZDQ5MmU3ZmY4NTA5OWYxOTY1NGMyYTY4ZjlmYjRiNDA5MzEwNjMyMGIxNTgzYjYmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0JnJlc3BvbnNlLWNvbnRlbnQtdHlwZT1pbWFnZSUyRnBuZyJ9.F415_jfcrlDSt6P7MlCl9QLaW1PNFckasEVw1VNZVOk)  




