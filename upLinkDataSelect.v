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
 *  file: upLinkDataSelect.v
 * 文件：upLinkDataSelect.v
 * 功能：根据FEC模式和数据速率选择和格式化输入数据
 *
 *  upLinkDataSelect
 *
 *  Controll signals :

 *  fecMode:
 *    0 - FEC 5
 *    1 - FEC 12
 *
 *  History:
 *  2016/05/30 Szymon Kulis    : Created
 *  2016/10/19 Jose Fonseca    : Modified
 *  2020/08/24 EBSM    : Removed clock input
 **/

// 上行链路数据选择器
// 根据FEC模式和数据速率选择和格式化输入数据
module upLinkDataSelect(

    // input data:
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

    // controll signals:
    input          fecMode,
    input          dataRate,

    // output data:
    output reg [233:0] dataFec5,
    output reg [205:0] dataFec12
);

  // tmrg default triplicate

  localparam FEC5  = 1'b0;
  localparam FEC12 = 1'b1;
  localparam DR5G  = 1'b0;
  localparam DR10G = 1'b1;

  always @* begin
      if (fecMode == FEC5) begin
        dataFec12 = 0;
        if (dataRate == DR10G) begin
          dataFec5 = {txIC, txEC, txDummyFec5[5:0], txDataGroup6,
                      txDataGroup5,
                      txDataGroup4,
                      txDataGroup3,
                      txDataGroup2,
                      txDataGroup1,
                      txDataGroup0};
        end
        else begin
          dataFec5 = {118'd0, txIC, txEC, txDataGroup6[15:0],
                      txDataGroup5[15:0],
                      txDataGroup4[15:0],
                      txDataGroup3[15:0],
                      txDataGroup2[15:0],
                      txDataGroup1[15:0],
                      txDataGroup0[15:0]};
        end
      end
      else begin
        dataFec5=0;
           if (dataRate == DR10G) begin
          dataFec12 = {txIC, txEC, txDummyFec12[9:0], txDataGroup5[31:0],
                       txDataGroup4[31:0],
                       txDataGroup3[31:0],
                       txDataGroup2[31:0],
                       txDataGroup1[31:0],
                       txDataGroup0[31:0]};
        end
        else begin
          dataFec12 = {104'd0, txIC, txEC, txDummyFec12[1:0], txDataGroup5[15:0],
                       txDataGroup4[15:0],
                       txDataGroup3[15:0],
                       txDataGroup2[15:0],
                       txDataGroup1[15:0],
                       txDataGroup0[15:0]};
        end
      end
    end
endmodule

