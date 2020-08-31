-- IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--use work.lpgbtfpga_package.all;
--=================================================================================================--
--#######################################   Entity   ##############################################--
--=================================================================================================--

entity lpgbtemul_top is
    generic(
        -- MGT-specific parameters
        -- Read your MGT user guide before connecting them		
        rxslide_pulse_duration : integer:= 2;  -- Duration of GT_RXSLIDE_OUT pulse
        rxslide_pulse_delay    : integer:= 128 -- Minimum time between two GT_RXSLIDE_OUT pulses
    );
    port(            
        -- DownLink
        downlinkClkEn_o    : out std_logic; 
        downLinkDataGroup0 : out std_logic_vector(15 downto 0);
        downLinkDataGroup1 : out std_logic_vector(15 downto 0);
        downLinkDataEc     : out std_logic_vector(1 downto 0);
        downLinkDataIc     : out std_logic_vector(1 downto 0);
        downlinkRdy_o      : out std_logic;
                           
        -- Uplink          
        uplinkClkEn_i      : in  std_logic;
        upLinkData0        : in  std_logic_vector(31 downto 0);
        upLinkData1        : in  std_logic_vector(31 downto 0);
        upLinkData2        : in  std_logic_vector(31 downto 0);
        upLinkData3        : in  std_logic_vector(31 downto 0);
        upLinkData4        : in  std_logic_vector(31 downto 0);
        upLinkData5        : in  std_logic_vector(31 downto 0);
        upLinkData6        : in  std_logic_vector(31 downto 0);
        upLinkDataIC       : in  std_logic_vector(1 downto 0);
        upLinkDataEC       : in  std_logic_vector(1 downto 0);
        uplinkRdy_o        : out std_logic;
                           
        -- Uplink mode     
        fecMode            : in  std_logic; -- 0=FEC5, 1=FEC12
        txDataRate         : in  std_logic; -- 1=5G  , 2=10G

		-- Transceiver     
        GT_RXUSRCLK_IN     : in  std_logic;
        GT_TXUSRCLK_IN     : in  std_logic;
        GT_RXSLIDE_OUT     : out std_logic;    
        GT_TXREADY_IN      : in  std_logic;
        GT_RXREADY_IN      : in  std_logic;
        GT_TXDATA_OUT      : out std_logic_vector(31 downto 0);
        GT_RXDATA_IN       : in  std_logic_vector(31 downto 0)

    ); 
end lpgbtemul_top;

--=================================================================================================--
--####################################   Architecture   ###########################################-- 
--=================================================================================================--

architecture behavioral of lpgbtemul_top is

    -- Downlink    
    signal dat_downLinkWord_fromMgt_s           : std_logic_vector(31 downto 0);
    signal sta_mgtRxRdy_s                       : std_logic;
    signal rst_pattsearch_s                     : std_logic;
    signal ctr_clkSlip_s                        : std_logic;
    signal sta_headeLocked_s                    : std_logic;
    signal sta_headerFlag_s                     : std_logic;
    signal sta_rxgbxRdy_s                       : std_logic;
    signal rst_datapath_s                       : std_logic;
    signal dat_downLinkWord_fromGb_s            : std_logic_vector(255 downto 0);
    signal dat_downLinkWord_fromGbInv_s         : std_logic_vector(63 downto 0);
    signal dat_downLinkWord_toPattSrch_s        : std_logic_vector(15 downto 0);
    signal clk_mgtRxUsrclk_s                    : std_logic;
    signal downlinkRdy_s0                       : std_logic;
    signal downlinkRdy_s1                       : std_logic;
    signal RX_CLKEn_s                           : std_logic;
    signal downLinkDataIc_s                     : std_logic_vector(1 downto 0);
    signal downLinkDataEc_s                     : std_logic_vector(1 downto 0);
    signal downLinkDataGroup1_s                 : std_logic_vector(15 downto 0);
    signal downLinkDataGroup0_s                 : std_logic_vector(15 downto 0);
    signal clk_dataFlag_rxGb_s                  : std_logic;

    -- Uplink
    signal clk_mgtTxUsrclk_s                    : std_logic;
    signal sta_mgtTxRdy_s                       : std_logic;
    signal uplinkClkEn_shgb_s                   : std_logic;
    signal sta_txGbRdy_s                        : std_logic;
    signal dat_upLinkWord_fromLpGBT_s           : std_logic_vector(255 downto 0);
    signal dat_upLinkWord_fromLpGBT_pipeline_s  : std_logic_vector(255 downto 0);
    signal dat_upLinkWord_toGb_s                : std_logic_vector(255 downto 0);
    signal dat_upLinkWord_toGb_pipeline_s       : std_logic_vector(255 downto 0);
    signal dat_upLinkWord_fromGb_s              : std_logic_vector(31 downto 0);
    signal rst_uplinkGb_s                       : std_logic;
    signal rst_uplinkGb_synch_s                 : std_logic;
    signal rst_uplinkMgt_s                      : std_logic;
    signal rst_uplinkInitDone_s                 : std_logic;
    signal rst_downlinkInitDone_s               : std_logic;
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

	---------------------------- Downlink ----------------------------
    sta_mgtRxRdy_s             <= GT_RXREADY_IN         ;
    rst_pattsearch_s           <= not(sta_mgtRxRdy_s)   ;
    rst_datapath_s             <= not(sta_headeLocked_s);

    clk_mgtRxUsrclk_s          <= GT_RXUSRCLK_IN        ;	
    GT_RXSLIDE_OUT             <= ctr_clkSlip_s         ;    
    dat_downLinkWord_fromMgt_s <= GT_RXDATA_IN          ;


    --Rdy process (delay from 1 clock)
    process(sta_rxgbxRdy_s, clk_mgtRxUsrclk_s)
    begin
        if sta_rxgbxRdy_s = '0' then
            downlinkRdy_o <= '0';
            downlinkRdy_s0 <= '0';
            downlinkRdy_s1 <= '0';
        elsif rising_edge(clk_mgtRxUsrclk_s) then
            if RX_CLKEn_s = '1' then
                downlinkRdy_s0 <= '1';
                downlinkRdy_s1 <= downlinkRdy_s0;
                downlinkRdy_o  <= downlinkRdy_s1;
            end if;
        end if;    
    end process;

    --! Multicycle path configuration (downlink)
    syncShiftRegDown_proc: process(sta_rxgbxRdy_s, clk_mgtRxUsrclk_s)
        variable cnter  : integer range 0 to 7;
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