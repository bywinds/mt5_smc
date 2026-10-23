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

## Project Introduction

Building an SMC EA is not difficult because of writing a BOS, OB, or FVG function; the real challenge is connecting swing highs/lows, structure breaks, order blocks, gaps, liquidity, previous-period highs/lows, weighted scoring, and order/close/risk control into a closed loop that actually runs.

This source code is an SMC strategy written on the MQL5 EA framework, in plaintext without encryption. It is suitable for studying smart money logic, saving time building modules from scratch, and facilitating secondary development.

<br>

### Core Content

* Complete MQL5 EA framework: OnInit / OnTick, triggered by new bars, CopyRates retrieves 200 completed bars, CTrade places orders, positions managed by magic + symbol;

* Multi-timeframe structure: executed on the current timeframe, H4 aggregates BOS/CHOCH and projects them back to the current timeframe, overlaying H4 previous highs/lows into scoring;

* Complete SMC core modules: swing highs/lows, BOS/CHOCH, order blocks OB, FVG, liquidity sweeps, previous-period highs/lows;

* Weighted scoring: previous highs/lows, aggregated BOS, BOS/CHOCH, OB retest, FVG retest, and liquidity sweep are scored separately; a net score above entryThreshold generates a signal, and the strongThreshold strong-signal score is already reserved;

* Structural stop-loss and take-profit: support/resistance, TP1/TP2 candidates, ATR buffer; fixed-point SL/TP combined with structural levels, with automatic validation of the broker's minimum stop distance;

* Execution risk control: maximum spread filter, margin check, lot size normalized by minimum/maximum/step, closing opposite positions by signal direction before opening, filtering positions by magic;

* Adjustable parameters: lot size, fixed SL/TP points, maximum spread, module weights, thresholds, swing length, liquidity range, etc. are all variables in the source code and can be modified as needed.

<br>

### Usage Notes

* Default single symbol, running on the current chart; example parameters are EURUSD, 1.10 lots, 200-point SL, 400-point TP, maximum spread 50. These are only source-code defaults; before live trading, be sure to adjust according to the symbol, capital, and broker rules;

* Backtest in the strategy tester first, then verify on a demo account/small capital; the SMC strategy general configuration scheme is not completely consistent with the source-code default parameters (e.g., thresholds 0.45/0.70/0.008 vs. source code 0.55/0.75/0.01). The source code prevails and can be unified as needed;

* The source code is for strategy research/secondary development purposes and does not include any profit promise; forex/CFD leverage carries significant risk.

<br>

### Suitable For

People with MQL5 basics who want to study SMC smart money logic, need plaintext EA source code for secondary development, and hope to save time building BOS/OB/FVG/liquidity modules.

<br>

### Risk Statement

1. This strategy source code is for learning and technical research only and does not constitute any investment advice. Please use this project within the scope permitted by laws and regulations;
<br>
2. The strategy source code is not a profit promise. Backtesting and historical performance do not represent future returns. If you need to run this strategy in live trading, please consider carefully;
<br>
3. Virtual goods; no returns after sale. Before purchasing, please confirm that you have an MQL5 Python strategy runtime environment.

<br>
<br>

___如果您对程序有疑问，可以向我询问，谢谢！If you have any questions about the program, feel free to ask me. Thank you___

![加好友](https://private-user-images.githubusercontent.com/19700138/682741720-c01f82c6-f631-4e7f-9d65-1441768d3e6f.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3OTI3NjExMzIsIm5iZiI6MTc5Mjc2MDgzMiwicGF0aCI6Ii8xOTcwMDEzOC82ODI3NDE3MjAtYzAxZjgyYzYtZjYzMS00ZTdmLTlkNjUtMTQ0MTc2OGQzZTZmLnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNjEwMjMlMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjYxMDIzVDEzMDcxMlomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWM3NDc4MGYwNzU5MjJlYzkwZDQ5MmU3ZmY4NTA5OWYxOTY1NGMyYTY4ZjlmYjRiNDA5MzEwNjMyMGIxNTgzYjYmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0JnJlc3BvbnNlLWNvbnRlbnQtdHlwZT1pbWFnZSUyRnBuZyJ9.F415_jfcrlDSt6P7MlCl9QLaW1PNFckasEVw1VNZVOk)  
