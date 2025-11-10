# lpGBT 模拟器 FPGA 实现

## 项目概述

本仓库包含 **lpGBT（低功耗千兆位收发器）模拟器**的 FPGA 实现，由 CERN（欧洲核子研究中心）为高能物理实验开发。lpGBT 模拟器允许在连接到真实 GBT ASIC 或 lpGBT 模拟器之前，在光纤环回模式下验证 FPGA 硬件。

该实现提供了完整的源代码，用于在各种数据速率（2.5Gb/s、5.12Gb/s、10.24Gb/s）下操作 FPGA 上行链路和下行链路，包括用于 2.5Gb/s 操作的关键解扰多项式实现，该功能通常仅由 lpGBT ASIC 执行。

### 背景说明

根据项目讨论记录，Steve 需要在简单的光纤环回模式下验证 FPGA 硬件，以便在连接到真实 GBT ASIC 或 lpGBT 模拟器之前进行测试。他需要能够在硬件中以 2.5Gb/s 的速率运行 FPGA 上行链路和下行链路。关键缺失的部分是用于解扰 2.5Gb/s 数据的多项式实现（通常只由 lpGBT ASIC 完成）。本仓库提供了这一关键功能的源代码实现。

## 主要特性

- **完整的上行和下行数据路径**：完整的发送/接收处理链
- **多种数据速率支持**：支持 5.12 Gb/s 和 10.24 Gb/s 操作
- **灵活的 FEC 模式**：FEC5 和 FEC12 前向纠错
- **加扰/解扰功能**：基于多项式的数据加扰以实现直流平衡
- **帧对齐**：自动头部检测和位滑动控制
- **时钟域交叉**：用于 MGT 到数据路径同步的变速箱模块
- **Reed-Solomon FEC**：多种 RS 编码器/解码器配置
- **伽罗瓦域运算**：用于 FEC 的完整 GF(2^m) 运算

## 系统架构

### 顶层模块：`lpgbtemul_top.vhd`

集成所有组件的主要实体：

```
┌─────────────────────────────────────────────────────────┐
│                    lpgbtemul_top                        │
├──────────────────┬──────────────────────────────────────┤
│  Downlink (RX)   │         Uplink (TX)                  │
├──────────────────┼──────────────────────────────────────┤
│  MGT RX Data     │         User Data (7 groups)         │
│       ↓          │                ↓                     │
│  Frame Aligner   │         TX Data Path                 │
│       ↓          │         - Data Select                │
│  RX Gearbox      │         - Scrambler                  │
│       ↓          │         - FEC Encoder                │
│  RX Data Path    │         - Interleaver                │
│  - Deinterleaver │                ↓                     │
│  - FEC Decoder   │         TX Gearbox                   │
│  - Descrambler   │                ↓                     │
│       ↓          │         MGT TX Data                  │
│  User Data       │                                       │
└──────────────────┴──────────────────────────────────────┘
```

## 模块说明

### 1. 上行链路（TX）数据路径

**文件**：`upLinkTxDataPath.v`

处理通过 MGT 传输的用户数据：

- **upLinkDataSelect.v**：根据 FEC 模式多路复用输入数据组并格式化
- **upLinkScrambler.v**：应用基于多项式的加扰以实现直流平衡
- **upLinkFECEncoder.v**：Reed-Solomon 前向纠错编码
- **upLinkInterleaver.v**：位交织以分散突发错误

**加扰器模块**：
- `scrambler58bitOrder58.v`：用于 FEC5 模式
- `scrambler60bitOrder58.v`：用于 FEC5 高速率模式
- `scrambler51bitOrder49.v`：用于 FEC12 模式
- `scrambler53bitOrder49.v`：用于 FEC12 高速率模式

### 2. 下行链路（RX）数据路径

**文件**：`downLinkRxDataPath.v`

处理从 MGT 接收的数据：

- **downLinkDeinterleaver.v**：反向位交织
- **downLinkFECDecoder.v**：Reed-Solomon 错误检测和纠正
- **descrambler36bitOrder36.v**：基于多项式的解扰
  - **多项式**：`Si = Di xnor Si-25 xnor Si-36`
  - 这是 2.5Gb/s 环回验证的关键组件

### 3. 变速箱模块

**文件**：`txgearbox.vhd`、`rxgearbox.vhd`

处理 MGT 和数据路径时钟之间的时钟域交叉：

- **TX 变速箱**：将 256 位数据路径字转换为 32 位 MGT 字
- **RX 变速箱**：将 32 位 MGT 字转换为 64 位数据路径字
- 实现相位对齐和过采样支持

### 4. 帧对齐

**文件**：`mgt_frameAligner_pv.vhd`

检测帧头并控制位滑动：

- 搜索头部模式 `0xF00F`
- 为 MGT 位对齐生成 `GT_RXSLIDE` 控制信号
- 提供头部锁定状态和时序标志

### 5. 前向纠错（FEC）

**Reed-Solomon 编码器**：
- `rs_encoder_N15K13.v`：用于 FEC5 模式的 RS(15,13)
- `rs_encoder_N31K29.v`：用于 FEC12 模式的 RS(31,29)

**Reed-Solomon 解码器**：
- `rs_decoder_N7K5.v`：用于下行链路 FEC 的 RS(7,5)

**伽罗瓦域运算**：
- `gf_add_*.v`：GF 加法运算
- `gf_mult_*.v`：GF 乘法运算
- `gf_multBy2_*.v`、`gf_multBy3_*.v`：优化的 GF 乘法
- `gf_inv_*.v`：GF 乘法逆元
- `gf_log_*.v`：用于乘法的 GF 对数

## 接口信号

### 下行链路接口
```vhdl
downlinkClkEn_o      : 时钟使能输出
downLinkDataGroup0/1 : 16 位用户数据组
downLinkDataEc       : EC（错误纠正）位
downLinkDataIc       : IC（内部控制）位
downlinkRdy_o        : 就绪标志
```

### 上行链路接口
```vhdl
uplinkClkEn_i        : 时钟使能输入
upLinkData0-6        : 七个 32 位用户数据组
upLinkDataIC         : IC 位
upLinkDataEC         : EC 位
uplinkRdy_o          : 就绪标志
```

### 控制信号
```vhdl
fecMode              : FEC 模式选择（0=FEC5，1=FEC12）
txDataRate           : 数据速率选择（0=5.12Gb/s，1=10.24Gb/s）
```

### MGT 接口
```vhdl
GT_RXUSRCLK_IN       : 来自 MGT 的 RX 用户时钟
GT_TXUSRCLK_IN       : 来自 MGT 的 TX 用户时钟
GT_RXSLIDE_OUT       : 到 MGT 的位滑动控制
GT_TXREADY_IN        : 来自 MGT 的 TX 就绪
GT_RXREADY_IN        : 来自 MGT 的 RX 就绪
GT_TXDATA_OUT        : 到 MGT 的 32 位 TX 数据
GT_RXDATA_IN         : 来自 MGT 的 32 位 RX 数据
```

## 环回验证使用方法

用于 2.5Gb/s 简单光纤环回模式下的 FPGA 硬件验证：

1. **配置 MGT**：设置多千兆位收发器以进行 2.5Gb/s 操作
2. **连接光纤环回**：将 TX 光输出连接到 RX 光输入
3. **初始化模拟器**：
   - 等待 `GT_RXREADY_IN` 和 `GT_TXREADY_IN` 
   - 监控 `uplinkRdy_o` 和 `downlinkRdy_o`
4. **发送测试数据**：使用 `uplinkClkEn_i` 将数据应用于 `upLinkData0-6`
5. **接收数据**：当 `downlinkClkEn_o` 被断言时从 `downLinkDataGroup0/1` 读取数据
6. **验证**：比较发送和接收的数据

解扰器实现（`descrambler36bitOrder36.v`）对于此环回操作至关重要，因为它反转了通常由 ASIC 执行的加扰。

## 文件组织

```
lpgbt-emul-learning/
├── README.md                     # 本文件
├── lpgbtemul_top.vhd            # 顶层 FPGA 模块
├── 上行链路 (TX) 模块：
│   ├── upLinkTxDataPath.v       # TX 数据路径控制器
│   ├── upLinkDataSelect.v       # 数据多路复用器
│   ├── upLinkScrambler.v        # 加扰器控制器
│   ├── upLinkFECEncoder.v       # FEC 编码
│   ├── upLinkInterleaver.v      # 位交织器
│   ├── scrambler58bitOrder58.v  # 58 位加扰器
│   ├── scrambler60bitOrder58.v  # 60 位加扰器
│   ├── scrambler51bitOrder49.v  # 51 位加扰器
│   └── scrambler53bitOrder49.v  # 53 位加扰器
├── 下行链路 (RX) 模块：
│   ├── downLinkRxDataPath.v     # RX 数据路径控制器
│   ├── downLinkDeinterleaver.v  # 位解交织器
│   ├── downLinkFECDecoder.v     # FEC 解码
│   └── descrambler36bitOrder36.v # 36 位解扰器
├── 变速箱模块：
│   ├── txgearbox.vhd            # TX 时钟域交叉
│   └── rxgearbox.vhd            # RX 时钟域交叉
├── 帧对齐：
│   └── mgt_frameAligner_pv.vhd  # 帧头检测
├── FEC 模块：
│   ├── rs_encoder_N15K13.v      # RS(15,13) 编码器
│   ├── rs_encoder_N31K29.v      # RS(31,29) 编码器
│   └── rs_decoder_N7K5.v        # RS(7,5) 解码器
└── 伽罗瓦域模块：
    ├── gf_add_3.v, gf_add_4.v, gf_add_5.v
    ├── gf_mult_3.v
    ├── gf_multBy2_3.v, gf_multBy2_4.v, gf_multBy2_5.v
    ├── gf_multBy3_4.v, gf_multBy3_5.v
    ├── gf_inv_3.v
    └── gf_log_3.v
```

## 开发历史

- **2015-2016**：CERN GBT 团队的初始开发
- **2016**：Szymon Kulis、José Fonseca 创建核心模块
- **2017**：Eduardo Mendes 的 FPGA 原型实现
- **贡献者**：Paulo Moreira、Julian Mendez 和 CERN EP-ESE-BE 团队

## 许可和使用

此 IP 块可免费用于高能物理（HEP）实验和其他科学研究目的。不允许对包含该 IP 的芯片进行商业开发。未经作者书面许可，您不得重新分发该 IP。必须将对 IP 的任何修改传达给作者。应在出版物、公开演示、用户手册和其他文档中确认 IP 的使用。

## 参考资料

- lpGBT 项目：CERN 的低功耗千兆位收发器
- GBT/lpGBT 文档：通过 CERN 获取
- 相关仓库：lpgbt-emul（在项目讨论中提到）

## 联系方式

有关此实现的问题，请参阅 CERN lpGBT 项目文档或联系 CERN EP-ESE-BE 团队。
