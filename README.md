# lpGBT Emulator FPGA Implementation

[English](#english) | [中文](#chinese)

---

<a name="english"></a>
## English Documentation

### Project Overview

This repository contains the FPGA implementation of the **lpGBT (Low Power Gigabit Transceiver) Emulator**, developed for CERN's high-energy physics experiments. The lpGBT emulator allows validation of FPGA hardware in fiber loopback mode before connecting to real GBT ASICs or lpGBT emulators.

The implementation provides complete source code for operating FPGA uplink and downlink at various data rates (2.5Gb/s, 5.12Gb/s, 10.24Gb/s), including the critical descrambling polynomial implementation for 2.5Gb/s operation, which is normally performed only by the lpGBT ASIC.

### Key Features

- **Full Uplink and Downlink Data Paths**: Complete TX/RX processing chains
- **Multiple Data Rates**: Supports 5.12 Gb/s and 10.24 Gb/s operation
- **Flexible FEC Modes**: FEC5 and FEC12 forward error correction
- **Scrambling/Descrambling**: Polynomial-based data scrambling for DC balance
- **Frame Alignment**: Automatic header detection and bit-slip control
- **Clock Domain Crossing**: Gearbox modules for MGT to datapath synchronization
- **Reed-Solomon FEC**: Multiple RS encoder/decoder configurations
- **Galois Field Arithmetic**: Complete GF(2^m) operations for FEC

### Architecture

#### Top-Level Module: `lpgbtemul_top.vhd`

The main entity that integrates all components:

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

### Module Descriptions

#### 1. Uplink (TX) Data Path

**File**: `upLinkTxDataPath.v`

Processes user data for transmission through the MGT:

- **upLinkDataSelect.v**: Multiplexes input data groups and formats based on FEC mode
- **upLinkScrambler.v**: Applies polynomial-based scrambling for DC balance
- **upLinkFECEncoder.v**: Reed-Solomon forward error correction encoding
- **upLinkInterleaver.v**: Bit interleaving to spread burst errors

**Scramblers**:
- `scrambler58bitOrder58.v`: For FEC5 mode
- `scrambler60bitOrder58.v`: For FEC5 high-rate mode
- `scrambler51bitOrder49.v`: For FEC12 mode
- `scrambler53bitOrder49.v`: For FEC12 high-rate mode

#### 2. Downlink (RX) Data Path

**File**: `downLinkRxDataPath.v`

Processes received data from the MGT:

- **downLinkDeinterleaver.v**: Reverses bit interleaving
- **downLinkFECDecoder.v**: Reed-Solomon error detection and correction
- **descrambler36bitOrder36.v**: Polynomial-based descrambling
  - **Polynomial**: `Si = Di xnor Si-25 xnor Si-36`
  - This is the critical component for 2.5Gb/s loopback validation

#### 3. Gearbox Modules

**Files**: `txgearbox.vhd`, `rxgearbox.vhd`

Handle clock domain crossing between MGT and datapath clocks:

- **TX Gearbox**: Converts 256-bit datapath words to 32-bit MGT words
- **RX Gearbox**: Converts 32-bit MGT words to 64-bit datapath words
- Implements phase alignment and oversampling support

#### 4. Frame Alignment

**File**: `mgt_frameAligner_pv.vhd`

Detects frame headers and controls bit-slip:

- Searches for header pattern `0xF00F`
- Generates `GT_RXSLIDE` control signal for MGT bit alignment
- Provides header lock status and timing flags

#### 5. Forward Error Correction (FEC)

**Reed-Solomon Encoders**:
- `rs_encoder_N15K13.v`: RS(15,13) for FEC5 mode
- `rs_encoder_N31K29.v`: RS(31,29) for FEC12 mode

**Reed-Solomon Decoder**:
- `rs_decoder_N7K5.v`: RS(7,5) for downlink FEC

**Galois Field Arithmetic**:
- `gf_add_*.v`: GF addition operations
- `gf_mult_*.v`: GF multiplication operations
- `gf_multBy2_*.v`, `gf_multBy3_*.v`: Optimized GF multiplications
- `gf_inv_*.v`: GF multiplicative inverse
- `gf_log_*.v`: GF logarithm for multiplication

### Interface Signals

#### Downlink Interface
```vhdl
downlinkClkEn_o      : Clock enable output
downLinkDataGroup0/1 : 16-bit user data groups
downLinkDataEc       : EC (Error Correction) bits
downLinkDataIc       : IC (Internal Control) bits
downlinkRdy_o        : Ready flag
```

#### Uplink Interface
```vhdl
uplinkClkEn_i        : Clock enable input
upLinkData0-6        : Seven 32-bit user data groups
upLinkDataIC         : IC bits
upLinkDataEC         : EC bits
uplinkRdy_o          : Ready flag
```

#### Control Signals
```vhdl
fecMode              : FEC mode selection (0=FEC5, 1=FEC12)
txDataRate           : Data rate selection (0=5G, 1=10G)
```

#### MGT Interface
```vhdl
GT_RXUSRCLK_IN       : RX user clock from MGT
GT_TXUSRCLK_IN       : TX user clock from MGT
GT_RXSLIDE_OUT       : Bit-slip control to MGT
GT_TXREADY_IN        : TX ready from MGT
GT_RXREADY_IN        : RX ready from MGT
GT_TXDATA_OUT        : 32-bit TX data to MGT
GT_RXDATA_IN         : 32-bit RX data from MGT
```

### Usage for Loopback Validation

For FPGA hardware validation in simple fiber loopback mode at 2.5Gb/s:

1. **Configure the MGT**: Set up the Multi-Gigabit Transceiver for 2.5Gb/s operation
2. **Connect Fiber Loopback**: Connect TX optical output to RX optical input
3. **Initialize the Emulator**: 
   - Wait for `GT_RXREADY_IN` and `GT_TXREADY_IN` 
   - Monitor `uplinkRdy_o` and `downlinkRdy_o`
4. **Send Test Data**: Apply data to `upLinkData0-6` with `uplinkClkEn_i`
5. **Receive Data**: Read data from `downLinkDataGroup0/1` when `downlinkClkEn_o` is asserted
6. **Verify**: Compare transmitted and received data

The descrambler implementation (`descrambler36bitOrder36.v`) is essential for this loopback operation, as it reverses the scrambling normally performed by the ASIC.

### File Organization

```
lpgbt-emul-learning/
├── README.md                     # This file
├── lpgbtemul_top.vhd            # Top-level FPGA module
├── Uplink (TX) Modules:
│   ├── upLinkTxDataPath.v       # TX data path controller
│   ├── upLinkDataSelect.v       # Data multiplexer
│   ├── upLinkScrambler.v        # Scrambler controller
│   ├── upLinkFECEncoder.v       # FEC encoding
│   ├── upLinkInterleaver.v      # Bit interleaver
│   ├── scrambler58bitOrder58.v  # 58-bit scrambler
│   ├── scrambler60bitOrder58.v  # 60-bit scrambler
│   ├── scrambler51bitOrder49.v  # 51-bit scrambler
│   └── scrambler53bitOrder49.v  # 53-bit scrambler
├── Downlink (RX) Modules:
│   ├── downLinkRxDataPath.v     # RX data path controller
│   ├── downLinkDeinterleaver.v  # Bit deinterleaver
│   ├── downLinkFECDecoder.v     # FEC decoding
│   └── descrambler36bitOrder36.v # 36-bit descrambler
├── Gearbox Modules:
│   ├── txgearbox.vhd            # TX clock domain crossing
│   └── rxgearbox.vhd            # RX clock domain crossing
├── Frame Alignment:
│   └── mgt_frameAligner_pv.vhd  # Frame header detection
├── FEC Modules:
│   ├── rs_encoder_N15K13.v      # RS(15,13) encoder
│   ├── rs_encoder_N31K29.v      # RS(31,29) encoder
│   └── rs_decoder_N7K5.v        # RS(7,5) decoder
└── Galois Field Modules:
    ├── gf_add_3.v, gf_add_4.v, gf_add_5.v
    ├── gf_mult_3.v
    ├── gf_multBy2_3.v, gf_multBy2_4.v, gf_multBy2_5.v
    ├── gf_multBy3_4.v, gf_multBy3_5.v
    ├── gf_inv_3.v
    └── gf_log_3.v
```

### Development History

- **2015-2016**: Initial development by CERN GBT Team
- **2016**: Core modules created by Szymon Kulis, José Fonseca
- **2017**: FPGA prototype implementation by Eduardo Mendes
- **Contributors**: Paulo Moreira, Julian Mendez, and CERN EP-ESE-BE team

### License and Usage

This IP block is free for HEP (High Energy Physics) experiments and other scientific research purposes. Commercial exploitation of a chip containing the IP is not permitted. You cannot redistribute the IP without written permission from the authors. Any modifications of the IP must be communicated back to the authors. The use of the IP should be acknowledged in publications, public presentations, user manuals, and other documents.

### References

- lpGBT Project: CERN's Low Power Gigabit Transceiver
- GBT/lpGBT Documentation: Available through CERN
- Related Repository: lpgbt-emul (mentioned in project discussions)

---

<a name="chinese"></a>
## 中文文档

### 项目概述

本仓库包含 **lpGBT（低功耗千兆位收发器）模拟器**的 FPGA 实现，由 CERN 高能物理实验开发。lpGBT 模拟器允许在连接到真实 GBT ASIC 或 lpGBT 模拟器之前，在光纤环回模式下验证 FPGA 硬件。

该实现提供了完整的源代码，用于在各种数据速率（2.5Gb/s、5.12Gb/s、10.24Gb/s）下操作 FPGA 上行链路和下行链路，包括用于 2.5Gb/s 操作的关键解扰多项式实现，该功能通常仅由 lpGBT ASIC 执行。

### 主要特性

- **完整的上行和下行数据路径**：完整的 TX/RX 处理链
- **多种数据速率**：支持 5.12 Gb/s 和 10.24 Gb/s 操作
- **灵活的 FEC 模式**：FEC5 和 FEC12 前向纠错
- **加扰/解扰**：基于多项式的数据加扰以实现直流平衡
- **帧对齐**：自动头部检测和位滑动控制
- **时钟域交叉**：用于 MGT 到数据路径同步的变速箱模块
- **Reed-Solomon FEC**：多种 RS 编码器/解码器配置
- **伽罗瓦域运算**：用于 FEC 的完整 GF(2^m) 运算

### 架构

#### 顶层模块：`lpgbtemul_top.vhd`

集成所有组件的主要实体：

```
┌─────────────────────────────────────────────────────────┐
│                    lpgbtemul_top                        │
├──────────────────┬──────────────────────────────────────┤
│  下行链路 (RX)   │         上行链路 (TX)                │
├──────────────────┼──────────────────────────────────────┤
│  MGT RX 数据     │         用户数据（7组）              │
│       ↓          │                ↓                     │
│  帧对齐器        │         TX 数据路径                  │
│       ↓          │         - 数据选择                   │
│  RX 变速箱       │         - 加扰器                     │
│       ↓          │         - FEC 编码器                 │
│  RX 数据路径     │         - 交织器                     │
│  - 解交织器      │                ↓                     │
│  - FEC 解码器    │         TX 变速箱                    │
│  - 解扰器        │                ↓                     │
│       ↓          │         MGT TX 数据                  │
│  用户数据        │                                       │
└──────────────────┴──────────────────────────────────────┘
```

### 模块说明

#### 1. 上行链路（TX）数据路径

**文件**：`upLinkTxDataPath.v`

处理通过 MGT 传输的用户数据：

- **upLinkDataSelect.v**：根据 FEC 模式多路复用输入数据组并格式化
- **upLinkScrambler.v**：应用基于多项式的加扰以实现直流平衡
- **upLinkFECEncoder.v**：Reed-Solomon 前向纠错编码
- **upLinkInterleaver.v**：位交织以分散突发错误

**加扰器**：
- `scrambler58bitOrder58.v`：用于 FEC5 模式
- `scrambler60bitOrder58.v`：用于 FEC5 高速率模式
- `scrambler51bitOrder49.v`：用于 FEC12 模式
- `scrambler53bitOrder49.v`：用于 FEC12 高速率模式

#### 2. 下行链路（RX）数据路径

**文件**：`downLinkRxDataPath.v`

处理从 MGT 接收的数据：

- **downLinkDeinterleaver.v**：反向位交织
- **downLinkFECDecoder.v**：Reed-Solomon 错误检测和纠正
- **descrambler36bitOrder36.v**：基于多项式的解扰
  - **多项式**：`Si = Di xnor Si-25 xnor Si-36`
  - 这是 2.5Gb/s 环回验证的关键组件

#### 3. 变速箱模块

**文件**：`txgearbox.vhd`、`rxgearbox.vhd`

处理 MGT 和数据路径时钟之间的时钟域交叉：

- **TX 变速箱**：将 256 位数据路径字转换为 32 位 MGT 字
- **RX 变速箱**：将 32 位 MGT 字转换为 64 位数据路径字
- 实现相位对齐和过采样支持

#### 4. 帧对齐

**文件**：`mgt_frameAligner_pv.vhd`

检测帧头并控制位滑动：

- 搜索头部模式 `0xF00F`
- 为 MGT 位对齐生成 `GT_RXSLIDE` 控制信号
- 提供头部锁定状态和时序标志

#### 5. 前向纠错（FEC）

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

### 接口信号

#### 下行链路接口
```vhdl
downlinkClkEn_o      : 时钟使能输出
downLinkDataGroup0/1 : 16 位用户数据组
downLinkDataEc       : EC（错误纠正）位
downLinkDataIc       : IC（内部控制）位
downlinkRdy_o        : 就绪标志
```

#### 上行链路接口
```vhdl
uplinkClkEn_i        : 时钟使能输入
upLinkData0-6        : 七个 32 位用户数据组
upLinkDataIC         : IC 位
upLinkDataEC         : EC 位
uplinkRdy_o          : 就绪标志
```

#### 控制信号
```vhdl
fecMode              : FEC 模式选择（0=FEC5，1=FEC12）
txDataRate           : 数据速率选择（0=5G，1=10G）
```

#### MGT 接口
```vhdl
GT_RXUSRCLK_IN       : 来自 MGT 的 RX 用户时钟
GT_TXUSRCLK_IN       : 来自 MGT 的 TX 用户时钟
GT_RXSLIDE_OUT       : 到 MGT 的位滑动控制
GT_TXREADY_IN        : 来自 MGT 的 TX 就绪
GT_RXREADY_IN        : 来自 MGT 的 RX 就绪
GT_TXDATA_OUT        : 到 MGT 的 32 位 TX 数据
GT_RXDATA_IN         : 来自 MGT 的 32 位 RX 数据
```

### 环回验证使用方法

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

### 文件组织

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

### 开发历史

- **2015-2016**：CERN GBT 团队的初始开发
- **2016**：Szymon Kulis、José Fonseca 创建核心模块
- **2017**：Eduardo Mendes 的 FPGA 原型实现
- **贡献者**：Paulo Moreira、Julian Mendez 和 CERN EP-ESE-BE 团队

### 许可和使用

此 IP 块可免费用于高能物理（HEP）实验和其他科学研究目的。不允许对包含该 IP 的芯片进行商业开发。未经作者书面许可，您不得重新分发该 IP。必须将对 IP 的任何修改传达给作者。应在出版物、公开演示、用户手册和其他文档中确认 IP 的使用。

### 参考资料

- lpGBT 项目：CERN 的低功耗千兆位收发器
- GBT/lpGBT 文档：通过 CERN 获取
- 相关仓库：lpgbt-emul（在项目讨论中提到）

---

## Contact / 联系方式

For questions or issues related to this implementation, please refer to the CERN lpGBT project documentation or contact the CERN EP-ESE-BE team.

有关此实现的问题，请参阅 CERN lpGBT 项目文档或联系 CERN EP-ESE-BE 团队。
