/** ****************************************************************************
 *  lpGBTX                                                                     *
 *  Copyright (C) 2011-2016 GBTX Team, CERN                                    *
 *                                                                             *
 *  This IP block is free for HEP experiments and other scientific research    *
 *  purposes. Commercial exploitation of a chip containing the IP is not       *
 *  permitted.  You can not redistribute the IP without written permission     *
 *  from the authors. Any modifications of the IP have to be communicated back *
 *  to the authors. The use of the IP should be acknowledged in publications,  *
 *  public presentations, user manual, and other documents.                    *
 *                                                                             *
 *  This IP is distributed in the hope that it will be useful, but WITHOUT ANY *
 *  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS  *
 *  FOR A PARTICULAR PURPOSE.                                                  *
 *                                                                             *
 *******************************************************************************
 *
 *  file: upLinkTxDataPath.v
 *  文件：upLinkTxDataPath.v
 *
 *  upLinkTxDataPath
 *  上行链路发送数据路径 - 处理用户数据并生成经过加扰、FEC编码和交织的上行链路帧
 *
 *  Controll signals :
 *  控制信号：
 *  txDataRate:
 *    ‘0’ - 5.12 Gb/s
 *    ‘1’ - 10.24 Gb/s
 *
 *  fecMode:
 *    ‘0’ - FEC 5
 *    ‘1’ - FEC 12
 *
 *  History:
 *  2016/05/20 Szymon Kulis    : Created
 *  2016/10/25 José Foseca     : Modified
 *  2016/12/08 Szymon Kulis    : BERT generator added
 *  2017/03/28 Eduardo Mendes  : LPGBT-FPGA prototype
 **/


module upLinkTxDataPath (
    // input cloks:
    // 输入时钟：
    input          clk,              // 时钟信号 / Clock signal

    // input data:
	input          dataEnable,	
    input  [31:0] txDataGroup0,
    input  [31:0] txDataGroup1,
    input  [31:0] txDataGroup2,
    input  [31:0] txDataGroup3,
    input  [31:0] txDataGroup4,
    input  [31:0] txDataGroup5,
    input  [31:0] txDataGroup6,
    input  [1:0]   txIC,
    input  [1:0]   txEC,
    input  [5:0]   txDummyFec5,
    input  [9:0]   txDummyFec12,

    // controll signals
    input          scramblerBypass,
    input          interleaverBypass,
    input          fecMode,
    input          txDataRate,
    input          fecDisable,
    input          scramblerReset,
    // output data
    output  [255:0] upLinkFrame
);

// -------------------------------------------------------------------------- //
// ------------- Triple Modular Redundancy Generator Directives ------------- //
// -------------------------------------------------------------------------- //
// tmrg default triplicate
// tmrg do_not_triplicate upLinkFrame
// -------------------------------------------------------------------------- //

  wire [233:0] dataFec5;
  wire [205:0] dataFec12;

  upLinkDataSelect ULDS(
    .dataFec12(dataFec12),
    .dataFec5(dataFec5),
    .dataRate(txDataRate),
    .fecMode(fecMode),
    .txDataGroup0(txDataGroup0),
    .txDataGroup1(txDataGroup1),
    .txDataGroup2(txDataGroup2),
    .txDataGroup3(txDataGroup3),
    .txDataGroup4(txDataGroup4),
    .txDataGroup5(txDataGroup5),
    .txDataGroup6(txDataGroup6),
    .txDummyFec5(txDummyFec5),
    .txDummyFec12(txDummyFec12),
    .txEC(txEC),
    .txIC(txIC)
  );

  wire [233:0] scrambledDataFec5;
  wire [205:0] scrambledDataFec12;

  upLinkScrambler UPS (
    .bypass(scramblerBypass),
    .clk(clk),
	.enable(dataEnable),
    .dataFec12(dataFec12),
    .dataFec5(dataFec5),
    .fecMode(fecMode),
    .reset(scramblerReset),
    .scrambledDataFec12(scrambledDataFec12),
    .scrambledDataFec5(scrambledDataFec5),
    .txDataRate(txDataRate)
  );

  wire [19:0] fec5;
  wire [47:0] fec12;

  upLinkFECEncoder ULFE (
    .dataFec12(scrambledDataFec12),
    .dataFec5(scrambledDataFec5),
    .fec12(fec12),
    .fec5(fec5),
    .drMode(txDataRate)
  );

  upLinkInterleaver ULI (
    .bypass(interleaverBypass),
    .dataFec12(scrambledDataFec12),
    .dataFec5(scrambledDataFec5),
    .fec12(fec12),
    .fec5(fec5),
    .fecMode(fecMode),
    .txDataRate(txDataRate),
    .upLinkFrame(upLinkFrame)
  );

endmodule
