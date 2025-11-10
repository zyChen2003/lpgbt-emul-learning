-- IEEE VHDL standard library:
-- IEEE VHDL 标准库
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--use work.lpgbtfpga_package.all;
--=================================================================================================--
--#######################################   Entity   ##############################################--
--=================================================================================================--
--=========================================  实体定义  ============================================--

-- lpGBT 模拟器顶层模块
-- lpGBT Emulator Top Module
-- 功能：实现完整的 lpGBT 上行链路（TX）和下行链路（RX）数据路径
-- Function: Implements complete lpGBT uplink (TX) and downlink (RX) data paths
entity lpgbtemul_top is
    generic(
        -- MGT-specific parameters
        -- MGT 特定参数
        -- Read your MGT user guide before connecting them
        -- 连接前请阅读您的 MGT 用户指南
        rxslide_pulse_duration : integer:= 2;  -- Duration of GT_RXSLIDE_OUT pulse / GT_RXSLIDE_OUT 脉冲持续时间
        rxslide_pulse_delay    : integer:= 128 -- Minimum time between two GT_RXSLIDE_OUT pulses / 两个 GT_RXSLIDE_OUT 脉冲之间的最小时间
    );
    port(            
        -- DownLink
        -- 下行链路（接收路径）
        downlinkClkEn_o    : out std_logic;                      -- 下行链路时钟使能输出 / Downlink clock enable output
        downLinkDataGroup0 : out std_logic_vector(15 downto 0);  -- 下行链路数据组0（16位）/ Downlink data group 0 (16-bit)
        downLinkDataGroup1 : out std_logic_vector(15 downto 0);  -- 下行链路数据组1（16位）/ Downlink data group 1 (16-bit)
        downLinkDataEc     : out std_logic_vector(1 downto 0);   -- 下行链路 EC（错误纠正）位 / Downlink EC (Error Correction) bits
        downLinkDataIc     : out std_logic_vector(1 downto 0);   -- 下行链路 IC（内部控制）位 / Downlink IC (Internal Control) bits
        downlinkRdy_o      : out std_logic;                      -- 下行链路就绪信号 / Downlink ready signal
                           
        -- Uplink
        -- 上行链路（发送路径）
        uplinkClkEn_i      : in  std_logic;                      -- 上行链路时钟使能输入 / Uplink clock enable input
        upLinkData0        : in  std_logic_vector(31 downto 0);  -- 上行链路数据组0（32位）/ Uplink data group 0 (32-bit)
        upLinkData1        : in  std_logic_vector(31 downto 0);  -- 上行链路数据组1（32位）/ Uplink data group 1 (32-bit)
        upLinkData2        : in  std_logic_vector(31 downto 0);  -- 上行链路数据组2（32位）/ Uplink data group 2 (32-bit)
        upLinkData3        : in  std_logic_vector(31 downto 0);  -- 上行链路数据组3（32位）/ Uplink data group 3 (32-bit)
        upLinkData4        : in  std_logic_vector(31 downto 0);  -- 上行链路数据组4（32位）/ Uplink data group 4 (32-bit)
        upLinkData5        : in  std_logic_vector(31 downto 0);  -- 上行链路数据组5（32位）/ Uplink data group 5 (32-bit)
        upLinkData6        : in  std_logic_vector(31 downto 0);  -- 上行链路数据组6（32位）/ Uplink data group 6 (32-bit)
        upLinkDataIC       : in  std_logic_vector(1 downto 0);   -- 上行链路 IC 位 / Uplink IC bits
        upLinkDataEC       : in  std_logic_vector(1 downto 0);   -- 上行链路 EC 位 / Uplink EC bits
        uplinkRdy_o        : out std_logic;                      -- 上行链路就绪信号 / Uplink ready signal
                           
        -- Uplink mode
        -- 上行链路模式配置
        fecMode            : in  std_logic; -- 0=FEC5, 1=FEC12 / FEC 模式选择：0=FEC5，1=FEC12
        txDataRate         : in  std_logic; -- 1=5G  , 2=10G / 发送数据速率：0=5.12Gb/s，1=10.24Gb/s

        -- Transceiver
        -- 收发器接口（MGT - Multi-Gigabit Transceiver）
        GT_RXUSRCLK_IN     : in  std_logic;                      -- MGT 接收用户时钟输入 / MGT RX user clock input
        GT_TXUSRCLK_IN     : in  std_logic;                      -- MGT 发送用户时钟输入 / MGT TX user clock input
        GT_RXSLIDE_OUT     : out std_logic;                      -- MGT 位滑动控制输出（用于帧对齐）/ MGT bit-slip control output (for frame alignment)
        GT_TXREADY_IN      : in  std_logic;                      -- MGT 发送就绪输入 / MGT TX ready input
        GT_RXREADY_IN      : in  std_logic;                      -- MGT 接收就绪输入 / MGT RX ready input
        GT_TXDATA_OUT      : out std_logic_vector(31 downto 0);  -- MGT 32位发送数据输出 / MGT 32-bit TX data output
        GT_RXDATA_IN       : in  std_logic_vector(31 downto 0)   -- MGT 32位接收数据输入 / MGT 32-bit RX data input

    ); 
end lpgbtemul_top;

--=================================================================================================--
--####################################   Architecture   ###########################################-- 
--=================================================================================================--
--=========================================  架构实现  ============================================--

architecture behavioral of lpgbtemul_top is

    -- Downlink
    -- 下行链路内部信号定义
    signal dat_downLinkWord_fromMgt_s           : std_logic_vector(31 downto 0);  -- 来自 MGT 的下行链路数据字 / Downlink word from MGT
    signal sta_mgtRxRdy_s                       : std_logic;                      -- MGT 接收就绪状态 / MGT RX ready status
    signal rst_pattsearch_s                     : std_logic;                      -- 模式搜索复位信号 / Pattern search reset
    signal ctr_clkSlip_s                        : std_logic;                      -- 时钟滑动控制 / Clock slip control
    signal sta_headeLocked_s                    : std_logic;                      -- 帧头锁定状态 / Header locked status
    signal sta_headerFlag_s                     : std_logic;                      -- 帧头标志 / Header flag
    signal sta_rxgbxRdy_s                       : std_logic;                      -- 接收变速箱就绪 / RX gearbox ready
    signal rst_datapath_s                       : std_logic;                      -- 数据路径复位 / Datapath reset
    signal dat_downLinkWord_fromGb_s            : std_logic_vector(255 downto 0); -- 来自变速箱的下行链路字 / Downlink word from gearbox
    signal dat_downLinkWord_fromGbInv_s         : std_logic_vector(63 downto 0);  -- 变速箱输出的反相数据 / Inverted gearbox output
    signal dat_downLinkWord_toPattSrch_s        : std_logic_vector(15 downto 0);  -- 送往模式搜索的数据 / Data to pattern search
    signal clk_mgtRxUsrclk_s                    : std_logic;                      -- MGT 接收用户时钟 / MGT RX user clock
    signal downlinkRdy_s0                       : std_logic;                      -- 下行链路就绪寄存器0 / Downlink ready register 0
    signal downlinkRdy_s1                       : std_logic;                      -- 下行链路就绪寄存器1 / Downlink ready register 1
    signal RX_CLKEn_s                           : std_logic;                      -- 接收时钟使能 / RX clock enable
    signal downLinkDataIc_s                     : std_logic_vector(1 downto 0);   -- 下行链路 IC 数据 / Downlink IC data
    signal downLinkDataEc_s                     : std_logic_vector(1 downto 0);   -- 下行链路 EC 数据 / Downlink EC data
    signal downLinkDataGroup1_s                 : std_logic_vector(15 downto 0);  -- 下行链路数据组1 / Downlink data group 1
    signal downLinkDataGroup0_s                 : std_logic_vector(15 downto 0);  -- 下行链路数据组0 / Downlink data group 0
    signal clk_dataFlag_rxGb_s                  : std_logic;                      -- 接收变速箱数据标志 / RX gearbox data flag

    -- Uplink
    -- 上行链路内部信号定义
    signal clk_mgtTxUsrclk_s                    : std_logic;                      -- MGT 发送用户时钟 / MGT TX user clock
    signal sta_mgtTxRdy_s                       : std_logic;                      -- MGT 发送就绪状态 / MGT TX ready status
    signal uplinkClkEn_shgb_s                   : std_logic;                      -- 上行链路变速箱时钟使能 / Uplink gearbox clock enable
    signal sta_txGbRdy_s                        : std_logic;                      -- 发送变速箱就绪 / TX gearbox ready
    signal dat_upLinkWord_fromLpGBT_s           : std_logic_vector(255 downto 0); -- 来自 lpGBT 数据路径的上行链路字 / Uplink word from lpGBT datapath
    signal dat_upLinkWord_fromLpGBT_pipeline_s  : std_logic_vector(255 downto 0); -- lpGBT 数据流水线寄存器 / lpGBT data pipeline register
    signal dat_upLinkWord_toGb_s                : std_logic_vector(255 downto 0); -- 送往变速箱的上行链路字 / Uplink word to gearbox
    signal dat_upLinkWord_toGb_pipeline_s       : std_logic_vector(255 downto 0); -- 变速箱输入流水线寄存器 / Gearbox input pipeline register
    signal dat_upLinkWord_fromGb_s              : std_logic_vector(31 downto 0);  -- 来自变速箱的上行链路字 / Uplink word from gearbox
    signal rst_uplinkGb_s                       : std_logic;                      -- 上行链路变速箱复位 / Uplink gearbox reset
    signal rst_uplinkGb_synch_s                 : std_logic;                      -- 上行链路变速箱同步复位 / Uplink gearbox synchronous reset
    signal rst_uplinkMgt_s                      : std_logic;                      -- 上行链路 MGT 复位 / Uplink MGT reset
    signal rst_uplinkInitDone_s                 : std_logic;                      -- 上行链路初始化完成 / Uplink initialization done
    signal rst_downlinkInitDone_s               : std_logic;                      -- 下行链路初始化完成 / Downlink initialization done
    signal upLinkData0_s                        : std_logic_vector(31 downto 0);
    signal upLinkData1_s                        : std_logic_vector(31 downto 0);
    signal upLinkData2_s                        : std_logic_vector(31 downto 0);
    signal upLinkData3_s                        : std_logic_vector(31 downto 0);
    signal upLinkData4_s                        : std_logic_vector(31 downto 0);
    signal upLinkData5_s                        : std_logic_vector(31 downto 0);
    signal upLinkData6_s                        : std_logic_vector(31 downto 0);
    signal upLinkDataIC_s                       : std_logic_vector(1 downto 0);
    signal upLinkDataEC_s                       : std_logic_vector(1 downto 0);

    component upLinkTxDataPath 
    port (
        clk                 : in  std_logic;
    	dataEnable          : in  std_logic;	
        txDataGroup0        : in  std_logic_vector(31 downto 0);
        txDataGroup1        : in  std_logic_vector(31 downto 0);
        txDataGroup2        : in  std_logic_vector(31 downto 0);
        txDataGroup3        : in  std_logic_vector(31 downto 0);
        txDataGroup4        : in  std_logic_vector(31 downto 0);
        txDataGroup5        : in  std_logic_vector(31 downto 0);
        txDataGroup6        : in  std_logic_vector(31 downto 0);
    	                    
        txIC                : in  std_logic_vector(  1 downto 0);
        txEC                : in  std_logic_vector(  1 downto 0);
        txDummyFec5         : in  std_logic_vector(  5 downto 0);
        txDummyFec12        : in  std_logic_vector(  9 downto 0);
        scramblerBypass     : in  std_logic;
        interleaverBypass   : in  std_logic;
        fecMode             : in  std_logic;
        txDataRate          : in  std_logic;
        fecDisable          : in  std_logic;
        scramblerReset      : in  std_logic;
        upLinkFrame         : out std_logic_vector(255 downto 0)
    );
    end component;
    
    component downLinkRxDataPath 
    port (
        clk                 : in  std_logic;
    	downLinkFrame       : in  std_logic_vector( 63 downto 0);                      
        dataStrobe          : out std_logic;
        dataOut             : out std_logic_vector( 31 downto 0);
        dataEC              : out std_logic_vector(  1 downto 0);
        dataIC              : out std_logic_vector(  1 downto 0);
        header              : out std_logic_vector(  3 downto 0);
        dataEnable          : in  std_logic;
        bypassDeinterleaver : in  std_logic;
        bypassFECDecoder    : in  std_logic;
        bypassDescrambler   : in  std_logic;
        fecCorrectionCount  : out std_logic_vector( 15 downto 0)
        );
    end component;

                
begin                 --========####   Architecture Body   ####========--
                      --========####     架构主体      ####========--

    ---------------------------- Downlink ----------------------------
    ---------------------------- 下行链路 ----------------------------
    -- 下行链路信号连接 / Downlink signal connections
    sta_mgtRxRdy_s             <= GT_RXREADY_IN         ;  -- MGT 接收就绪状态 / MGT RX ready status
    rst_pattsearch_s           <= not(sta_mgtRxRdy_s)   ;  -- 模式搜索复位（MGT 未就绪时复位）/ Pattern search reset (reset when MGT not ready)
    rst_datapath_s             <= not(sta_headeLocked_s);  -- 数据路径复位（帧头未锁定时复位）/ Datapath reset (reset when header not locked)

    clk_mgtRxUsrclk_s          <= GT_RXUSRCLK_IN        ;  -- MGT 接收时钟 / MGT RX clock
    GT_RXSLIDE_OUT             <= ctr_clkSlip_s         ;  -- 位滑动控制输出 / Bit-slip control output
    dat_downLinkWord_fromMgt_s <= GT_RXDATA_IN          ;  -- MGT 接收数据 / MGT RX data


    --Rdy process (delay from 1 clock)
    --就绪处理进程（延迟1个时钟）
    -- 功能：产生延迟的下行链路就绪信号，用于时序对齐
    -- Function: Generate delayed downlink ready signal for timing alignment
    process(sta_rxgbxRdy_s, clk_mgtRxUsrclk_s)
    begin
        if sta_rxgbxRdy_s = '0' then
            downlinkRdy_o <= '0';
            downlinkRdy_s0 <= '0';
            downlinkRdy_s1 <= '0';
        elsif rising_edge(clk_mgtRxUsrclk_s) then
            if RX_CLKEn_s = '1' then
                downlinkRdy_s0 <= '1';                      -- 第一级寄存器 / First stage register
                downlinkRdy_s1 <= downlinkRdy_s0;           -- 第二级寄存器 / Second stage register
                downlinkRdy_o  <= downlinkRdy_s1;           -- 输出寄存器 / Output register
            end if;
        end if;    
    end process;

    --! Multicycle path configuration (downlink)
    --! 多周期路径配置（下行链路）
    -- 功能：生成下行链路时钟使能信号，用于跨时钟域同步
    -- Function: Generate downlink clock enable for clock domain crossing
    syncShiftRegDown_proc: process(sta_rxgbxRdy_s, clk_mgtRxUsrclk_s)
        variable cnter  : integer range 0 to 7;  -- 计数器，用于产生时钟使能 / Counter for clock enable generation
    begin
    
        if sta_rxgbxRdy_s = '0' then
              cnter              := 0;
              RX_CLKEn_s         <= '0';
              rst_downlinkInitDone_s <= '0';
              
        elsif rising_edge(clk_mgtRxUsrclk_s) then
            if clk_dataFlag_rxGb_s = '1' then
                cnter            := 0;
                rst_downlinkInitDone_s <= '1';
            elsif rst_downlinkInitDone_s = '1' then
                cnter            := cnter + 1;
            end if;
            RX_CLKEn_s           <= '0';
            if cnter = 4 then
                RX_CLKEn_s       <= rst_downlinkInitDone_s;
            end if;              
        end if;
    end process;
   
    -- Pattern aligner
    mgt_framealigner_inst: entity work.mgt_framealigner
        GENERIC map (
            c_wordRatio                      => 8,
            c_headerPattern                  => x"F00F",
            c_wordSize                       => 32,
            c_allowedFalseHeader             => 32,
            c_allowedFalseHeaderOverN        => 40,
            c_requiredTrueHeader             => 30,
            c_bitslip_mindly                 => rxslide_pulse_duration,
            c_bitslip_waitdly                => rxslide_pulse_delay

        )
        PORT map (     
            -- Clock(s)
            clk_pcsRx_i                      => clk_mgtRxUsrclk_s,
            
            -- Reset(s)
            rst_pattsearch_i                 => rst_pattsearch_s,
            
            -- Control
            cmd_bitslipCtrl_o                => ctr_clkSlip_s,
            
            -- Status
            sta_headerLocked_o               => sta_headeLocked_s,
            sta_headerFlag_o                 => sta_headerFlag_s,
            sta_bitSlipEven_o => open,
            -- Data
            dat_word_i                       => dat_downLinkWord_toPattSrch_s
       );

    dat_downLinkWord_toPattSrch_s <= dat_downLinkWord_fromMgt_s(24) & dat_downLinkWord_fromMgt_s(25) & dat_downLinkWord_fromMgt_s(26) & dat_downLinkWord_fromMgt_s(27) & 
                                     dat_downLinkWord_fromMgt_s(16) & dat_downLinkWord_fromMgt_s(17) & dat_downLinkWord_fromMgt_s(18) & dat_downLinkWord_fromMgt_s(19) & 
                                     dat_downLinkWord_fromMgt_s(8) & dat_downLinkWord_fromMgt_s(9) & dat_downLinkWord_fromMgt_s(10) & dat_downLinkWord_fromMgt_s(11) & 
                                     dat_downLinkWord_fromMgt_s(3) & dat_downLinkWord_fromMgt_s(2) & dat_downLinkWord_fromMgt_s(1) & dat_downLinkWord_fromMgt_s(0);

    -- Downlink gearbox
    rxGearbox_inst: entity work.rxGearbox
        generic map(
            c_clockRatio                  => 8,
            c_inputWidth                  => 32,
            c_outputWidth                 => 64,
            c_counterInitValue            => 2
        )
        port map(
            -- Clock and reset
            clk_inClk_i                   => clk_mgtRxUsrclk_s,
            clk_outClk_i                  => clk_mgtRxUsrclk_s,
            clk_clkEn_i                   => sta_headerFlag_s,
            clk_dataFlag_o                => clk_dataFlag_rxGb_s,
            rst_gearbox_i                 => rst_datapath_s,

            -- Data
            dat_inFrame_i                 => dat_downLinkWord_fromMgt_s,
            dat_outFrame_o                => dat_downLinkWord_fromGb_s,
            
            -- Status
            sta_gbRdy_o                   => sta_rxgbxRdy_s
        );

    rxdatapath_inst : downLinkRxDataPath
        port map (
            clk                   => clk_mgtRxUsrclk_s,
            downLinkFrame         => dat_downLinkWord_fromGb_s(63 downto 0),
            dataStrobe            => open, 
            dataOut(15 downto  0) => downLinkDataGroup0_s,
            dataOut(31 downto 16) => downLinkDataGroup1_s,
            dataEC                => downLinkDataEc_s,
            dataIC                => downLinkDataIc_s,
            header                => open,
            dataEnable            => RX_CLKEn_s,
            bypassDeinterleaver   => '0',
            bypassFECDecoder      => '0',
            bypassDescrambler     => '0',
            fecCorrectionCount    => open
        );

    downlinkClkEn_o                 <= RX_CLKEn_s;    
    downLinkDataGroup0              <= downLinkDataGroup0_s;
    downLinkDataGroup1              <= downLinkDataGroup1_s;
    downLinkDataEc                  <= downLinkDataEc_s;
    downLinkDataIc                  <= downLinkDataIc_s;
    -------------------------------------------------------------------

	---------------------------- Uplink -------------------------------    
    sta_mgtTxRdy_s    <= GT_TXREADY_IN;  
    rst_uplinkGb_s    <= not(sta_mgtTxRdy_s);
    uplinkRdy_o       <= sta_txGbRdy_s;
    clk_mgtTxUsrclk_s <= GT_TXUSRCLK_IN;

    -- Multicycle path configuration
    syncShiftRegUp_proc: process(rst_uplinkGb_s, clk_mgtTxUsrclk_s)
        variable cnter  : integer range 0 to 7;
    begin
        if rst_uplinkGb_s = '1' then
              cnter                := 0;
              uplinkClkEn_shgb_s   <= '0';
              rst_uplinkGb_synch_s <= '1';
              rst_uplinkInitDone_s <= '0';
              upLinkData0_s        <= (others => '0');
              upLinkData1_s        <= (others => '0');
              upLinkData2_s        <= (others => '0');
              upLinkData3_s        <= (others => '0');
              upLinkData4_s        <= (others => '0');
              upLinkData5_s        <= (others => '0');
              upLinkData6_s        <= (others => '0');
              upLinkDataIC_s       <= (others => '0');
              upLinkDataEC_s       <= (others => '0');
        elsif rising_edge(clk_mgtTxUsrclk_s) then
            if uplinkClkEn_i = '1' then
                cnter                := 0;
                upLinkData0_s        <= upLinkData0;
                upLinkData1_s        <= upLinkData1;
                upLinkData2_s        <= upLinkData2;
                upLinkData3_s        <= upLinkData3;
                upLinkData4_s        <= upLinkData4;
                upLinkData5_s        <= upLinkData5;
                upLinkData6_s        <= upLinkData6;
                upLinkDataIC_s       <= upLinkDataIC;
                upLinkDataEC_s       <= upLinkDataEC;
                rst_uplinkInitDone_s <= '1';
            elsif rst_uplinkInitDone_s = '1' then
                cnter            := cnter + 1;
            end if;
            uplinkClkEn_shgb_s           <= '0';
            if cnter = 4 then
                uplinkClkEn_shgb_s       <= '1';
                rst_uplinkGb_synch_s     <= rst_uplinkGb_s or not(rst_uplinkInitDone_s);
            end if;              
        end if;
    end process;

    txdatapath_inst : upLinkTxDataPath
        port map (
            clk                   => clk_mgtTxUsrclk_s,
            dataEnable            => uplinkClkEn_i, 
            txDataGroup0          => upLinkData0_s,
            txDataGroup1          => upLinkData1_s,
            txDataGroup2          => upLinkData2_s,
            txDataGroup3          => upLinkData3_s,
            txDataGroup4          => upLinkData4_s,
            txDataGroup5          => upLinkData5_s,
            txDataGroup6          => upLinkData6_s,
            txIC                  => upLinkDataIC_s,
            txEC                  => upLinkDataEC_s,
            txDummyFec5           => "001100",
            txDummyFec12          => "1001110011",
            scramblerBypass       => '0',
            interleaverBypass     => '0',
            fecMode               => fecMode,
            txDataRate            => txDataRate,
            fecDisable            => '0',
            scramblerReset        => rst_uplinkGb_s,
            upLinkFrame           => dat_upLinkWord_fromLpGBT_s
        );

    upLinkPipelineBeforeOversampling_proc: process(rst_uplinkGb_s, clk_mgtTxUsrclk_s)
      begin
        if rst_uplinkGb_s = '1' then
            dat_upLinkWord_fromLpGBT_pipeline_s <= (others => '0');
        elsif rising_edge(clk_mgtTxUsrclk_s) then
            if uplinkClkEn_i='1' then
              dat_upLinkWord_fromLpGBT_pipeline_s <= dat_upLinkWord_fromLpGBT_s;
            end if;
        end if;      
    end process;  

    oversampler_gen: for i in 0 to 127 generate
        oversampler_ph_gen: for j in 0 to 1 generate
            dat_upLinkWord_toGb_s((i*2)+j)  <= dat_upLinkWord_fromLpGBT_pipeline_s(i) when txDataRate = '0' else
                                               dat_upLinkWord_fromLpGBT_pipeline_s((i*2)+j);
        end generate;
    end generate;	

    upLinkPipelineAfterOversampling_proc: process(rst_uplinkGb_s, clk_mgtTxUsrclk_s)
      begin
        if rst_uplinkGb_s = '1' then
            dat_upLinkWord_toGb_pipeline_s <= (others => '0');
        elsif rising_edge(clk_mgtTxUsrclk_s) then
            if uplinkClkEn_shgb_s = '1' then
              dat_upLinkWord_toGb_pipeline_s <= dat_upLinkWord_toGb_s;
            end if;
        end if;      
      end process; 

    txGearbox_inst: entity work.txGearbox
        generic map (
            c_clockRatio                  => 8                             ,
            c_inputWidth                  => 256                           ,
            c_outputWidth                 => 32
        )
        port map (
            -- Clock and reset
            clk_inClk_i                   => clk_mgtTxUsrclk_s             , 
            clk_clkEn_i                   => uplinkClkEn_shgb_s            ,
            clk_outClk_i                  => clk_mgtTxUsrclk_s             ,
            rst_gearbox_i                 => rst_uplinkGb_synch_s          ,
            dat_inFrame_i                 => dat_upLinkWord_toGb_pipeline_s,
            dat_outFrame_o                => dat_upLinkWord_fromGb_s       ,
            sta_gbRdy_o                   => sta_txGbRdy_s
        );

    GT_TXDATA_OUT     <= dat_upLinkWord_fromGb_s;
    -------------------------------------------------------------------

end behavioral;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--