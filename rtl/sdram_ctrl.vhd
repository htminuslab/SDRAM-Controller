-------------------------------------------------------------------------------
-- SDRAM Controller core                                                     --
-------------------------------------------------------------------------------
-- Project       : SDRAM                                                     --
-- Unit          : sdram_ctrl                                                --
-- Library       : sdram                                                     --
-- Author        : H. Tiggeler                                               --
--                                                                           --
-- Version       : 0.1   18/07/07                                            --
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.NUMERIC_STD.all;

USE work.sdram_pack.all;

entity sdram_ctrl is
    port( 
        abus        : in     std_logic_vector (23 downto 0);
        clk         : in     std_logic;
        csn         : in     std_logic;
        dbus_in     : in     std_logic_vector (7 downto 0);
        rdn         : in     std_logic;
        resetn      : in     std_logic;
        sdram_clk   : in     std_logic;
        wrn         : in     std_logic;
        dbus_out    : out    std_logic_vector (7 downto 0);
        initdone    : out    std_logic;
        ready       : out    std_logic;
        sdram_a     : out    std_logic_vector (11 downto 0);
        sdram_ba    : out    std_logic_vector (1 downto 0);
        sdram_cas_n : out    std_logic;
        sdram_cke   : out    std_logic;
        sdram_cs_n  : out    std_logic;
        sdram_dqm   : out    std_logic_vector (3 downto 0);
        sdram_ras_n : out    std_logic;
        sdram_we_n  : out    std_logic;
        sdram_dq    : inout  std_logic_vector (31 downto 0)
    );
end sdram_ctrl ;

architecture struct of sdram_ctrl is

    signal a10         : std_logic;
    signal cmd         : std_logic_vector(3 downto 0);
    signal latch_dqm   : std_logic;
    signal latch_mode  : std_logic;
    signal latch_row   : std_logic;
    signal latch_word  : std_logic;
    signal rd          : std_logic;
    signal refresh_req : std_logic;
    signal rlatch      : std_logic;
    signal same_row    : std_logic;
    signal same_word   : std_logic;
    signal wr          : std_logic;

    signal initdone_internal : std_logic;

    signal refresh_cnt : integer RANGE 4095 DOWNTO 0;
    signal rowaddr : std_logic_vector(13 downto 0);
    signal coladdr : std_logic_vector(7 downto 0);
    signal dbus32_s : std_logic_vector(31 downto 0);

    component fsm
    port (
        clk         : in     std_logic ;
        rd          : in     std_logic ;
        refresh_req : in     std_logic ;
        resetn      : in     std_logic ;
        same_row    : in     std_logic ;
        same_word   : in     std_logic ;
        wr          : in     std_logic ;
        a10         : out    std_logic ;
        cmd         : out    std_logic_vector (3 downto 0);
        initdone    : out    std_logic ;
        latch_dqm   : out    std_logic ;
        latch_mode  : out    std_logic ;
        latch_row   : out    std_logic ;
        latch_word  : out    std_logic ;
        ready       : out    std_logic ;
        rlatch      : out    std_logic 
    );
    end component;


begin
  
    rd<='1' when CSN='0' AND rdn='0' else '0';
    wr<='1' when CSN='0' AND wrn='0' else '0';      

    -- latch/compare 14 bits Bank Select and Row address 
    -- BA1..BA0 = A23..A22
    -- A11..A0  = A21..A10
    process (clk,resetn)                                                                                    
        begin
            if resetn='0' then 
                rowaddr  <= (others => '1');
                coladdr  <= (others => '1');
            elsif (rising_edge(clk)) then 
                if (latch_row='1') then
                    rowaddr <= abus(23 downto 10);
                end if;
                if (latch_word='1') then
                    coladdr <= abus(9 downto 2);
                end if;
            end if;   
    end process;                                                
    
    same_row  <= '1' when rowaddr=abus(23 downto 10) else '0';
    same_word <= '1' when coladdr=abus(9 downto 2) else '0';

    sdram_cke <= '1';
    
    ---------------------------------------------------------------------------
    -- SDRAM Command
    ---------------------------------------------------------------------------
    sdram_cs_n <=cmd(3);
    sdram_ras_n<=cmd(2);
    sdram_cas_n<=cmd(1);
    sdram_we_n <=cmd(0);

    ---------------------------------------------------------------------------
    -- SDRAM Row/Column Address Generation
    -- abus1..0 used for Byte select
    ---------------------------------------------------------------------------
    process (resetn,sdram_clk)       
        begin
            if (resetn='0') then
                sdram_a  <= (others => '1');
            elsif falling_edge(sdram_clk) then          -- Note falling edge!      
                if (latch_row='1') then                 -- Latch Row
                    sdram_a  <= abus(21 downto 10); 
                elsif (latch_mode='1') then             -- Latch Mode Word
                    sdram_a  <= MODE_WORD;               
                else                                    -- Latch Column
                    sdram_a <= '-' & a10 & abus(11 downto 2); 
                end if;                                  
            end if;          
    end process;
    sdram_ba <= abus(23 downto 22); 
    
    ---------------------------------------------------------------------------
    -- SDRAM Byte Control
    ---------------------------------------------------------------------------
    process (resetn,sdram_clk)      
        begin 
            if (resetn='0') then
                sdram_dqm <= (others => '1');
            elsif falling_edge(sdram_clk) then              
                if (latch_dqm='1') then
                    if (wr='1') then
                        case abus(1 downto 0) is
                            when "00"   => sdram_dqm(3)<='1';sdram_dqm(2)<='1';sdram_dqm(1)<='1';sdram_dqm(0)<='0'; 
                            when "01"   => sdram_dqm(3)<='1';sdram_dqm(2)<='1';sdram_dqm(1)<='0';sdram_dqm(0)<='1';
                            when "10"   => sdram_dqm(3)<='1';sdram_dqm(2)<='0';sdram_dqm(1)<='1';sdram_dqm(0)<='1';
                            when others => sdram_dqm(3)<='0';sdram_dqm(2)<='1';sdram_dqm(1)<='1';sdram_dqm(0)<='1';          
                        end case;  
                     elsif (rd='1') then
                       sdram_dqm <= (others => '0');           -- Read all 32bits
                    end if;
                else
                    sdram_dqm <= (others => '1');
                end if;  
            end if;              
    end process;
    ---------------------------------------------------------------------------
    -- SDRAM Input Bus Steering
    ---------------------------------------------------------------------------
    process (resetn,sdram_clk)       
        begin
            if (resetn='0') then
                dbus32_s <= (others => '0');
            elsif rising_edge(sdram_clk) then              
                if (rlatch='1') then
                    dbus32_s <=sdram_dq;
                end if;  
            end if;              
    end process;   
    
    process (abus,dbus32_s)       
        begin
            case abus(1 downto 0) is
                when "00"   => dbus_out<= dbus32_s( 7 downto 0); 
                when "01"   => dbus_out<= dbus32_s(15 downto 8);
                when "10"   => dbus_out<= dbus32_s(23 downto 16);
                when others => dbus_out<= dbus32_s(31 downto 24);          
            end case; 
    end process;   
    
    ---------------------------------------------------------------------------
    -- SDRAM I/O Tri-State Driver
    ---------------------------------------------------------------------------
    process (cmd,dbus_in) 
        begin  
            if cmd=WRITEC then
                sdram_dq<= dbus_in & dbus_in & dbus_in & dbus_in; 
            else 
                sdram_dq<= (others => 'Z');
            end if;
    end process;   
        
    process (clk)                                                                                    
        begin
            if (rising_edge(clk)) then 
                if (cmd=AUTO_REFRESH OR initdone_internal='0') then
                    refresh_cnt <= tREF_CYCLES;
                    refresh_req <= '0'; 
                else
                    if (refresh_cnt=0) then
                        refresh_req <= '1';
                    else        
                        refresh_cnt <= refresh_cnt - 1;
                        refresh_req <= '0';
                    end if;
                end if;
            end if;   
    end process;                                            

    -- pragma synthesis_off
    assert (CLK_PERIOD>=5) report "Minimum clock period is 5ns, for lower values updated the integer ranges" severity failure;
    -- pragma synthesis_on                            

    U_0 : fsm
        port map (
            clk         => clk,
            rd          => rd,
            refresh_req => refresh_req,
            resetn      => resetn,
            same_row    => same_row,
            same_word   => same_word,
            wr          => wr,
            a10         => a10,
            cmd         => cmd,
            initdone    => initdone_internal,
            latch_dqm   => latch_dqm,
            latch_mode  => latch_mode,
            latch_row   => latch_row,
            latch_word  => latch_word,
            ready       => ready,
            rlatch      => rlatch
        );

    -- Implicit buffered output assignments
    initdone <= initdone_internal;

end struct;
