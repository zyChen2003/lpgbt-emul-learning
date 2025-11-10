/* Module: Descrambler36bitOrder36                                      */
/* 模块：36位解扰器，36阶                                                */
/* Created: Paulo Moreira, 2015/09/15                                        */
/* 创建者：Paulo Moreira，2015/09/15                                      */
/* Institute: CERN                                                           */
/* 机构：CERN（欧洲核子研究中心）                                        */
/* Version: 1.0                                                              */
/* 版本：1.0                                                               */

/* Descrambler width: 36 - bits                                              */
/* 解扰器宽度：36位                                                        */
/* Descrambler order: 36                                                     */
/* 解扰器阶数：36                                                          */
/* Recursive equation used for the scrambler: Si = Di xnor Si-25 xnor Si-36  */
/* 加扰器使用的递归方程：Si = Di xnor Si-25 xnor Si-36                   */
/* 功能说明：这是用于2.5Gb/s环回验证的关键组件，实现了数据解扰         */
/* Function: Critical component for 2.5Gb/s loopback validation, implements data descrambling */

`timescale 1 ps / 1 ps

module descrambler36bitOrder36(
    input [35:0] scrambledData,      // 加扰数据输入 / Scrambled data input
    input clock,                     // 时钟信号 / Clock signal
	input enable,                    // 使能信号 / Enable signal
    input bypass,                    // 旁路模式（跳过解扰）/ Bypass mode (skip descrambling)
    output reg [35:0] descrambledData // 解扰数据输出 / Descrambled data output
    );

// 内部寄存器和信号定义
// Internal registers and signal definitions
reg  [35:0] memoryRegister;                        // 存储寄存器（保存前一个加扰数据）/ Memory register (stores previous scrambled data)
wire [35:0] iMemoryRegister;                       // 内部存储寄存器信号 / Internal memory register signal
wire [35:0] iMemoryRegisterVoted = iMemoryRegister; // 投票后的存储寄存器（用于容错）/ Voted memory register (for fault tolerance)

wire [35:0] iDescrambledData;                      // 内部解扰数据信号 / Internal descrambled data signal
wire [35:0] iDescrambledDataVoted = iDescrambledData; // 投票后的解扰数据（用于容错）/ Voted descrambled data (for fault tolerance)

// 时钟边沿触发的寄存器更新
// Clock edge triggered register update
always @(posedge clock)
    begin
	if(enable==1'b1) begin
		memoryRegister  <= iMemoryRegisterVoted;   // 更新存储寄存器 / Update memory register
		descrambledData <= iDescrambledDataVoted;   // 更新解扰数据输出 / Update descrambled data output
	end	
end

// Descrambler polynomial and bypass mux
// 解扰多项式和旁路多路复用器
// 实现递归方程：Si = Di xnor Si-25 xnor Si-36
// Implements recursive equation: Si = Di xnor Si-25 xnor Si-36
assign
    // 高位部分（35:25）：当前数据 XNOR 延迟25位的数据 XNOR 延迟36位的数据
    // High bits (35:25): current data XNOR data delayed by 25 bits XNOR data delayed by 36 bits
    iDescrambledData[35:25] = (bypass)? scrambledData[35:25] : scrambledData[35:25] ~^ scrambledData[10:0]  ~^ memoryRegister[35:25],
    // 低位部分（24:0）：当前数据 XNOR 延迟36位的数据 XNOR 延迟25位的数据
    // Low bits (24:0): current data XNOR data delayed by 36 bits XNOR data delayed by 25 bits
    iDescrambledData[24:0]  = (bypass)? scrambledData[34:0]  : scrambledData[24:0]  ~^ memoryRegister[35:11] ~^ memoryRegister[24:0],
    // 存储寄存器更新：保存当前加扰数据用于下一周期
    // Memory register update: save current scrambled data for next cycle
    iMemoryRegister[35:0]   = (bypass)? 36'h000000000 : scrambledData[35:0];
    
endmodule
