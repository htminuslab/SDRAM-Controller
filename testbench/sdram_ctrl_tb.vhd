-------------------------------------------------------------------------------
-- SDRAM Controller core                                                     --
-------------------------------------------------------------------------------
-- Project       : SDRAM                                                     --
-- Unit          : Top level Testbench module                                --
-- Library       : sdram                                                     --
--                                                                           --
-- Version       : 0.1   18/07/07                                            --
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.NUMERIC_STD.all;

entity sdram_ctrl_tb is
end sdram_ctrl_tb ;

architecture struct of sdram_ctrl_tb is

    signal abus        : std_logic_vector(23 downto 0);
    signal ale         : std_logic;
    signal clk         : std_logic;
    signal csn         : std_logic;
    signal dbus_in     : std_logic_vector(7 downto 0);
    signal dbus_out    : std_logic_vector(7 downto 0);
    signal initdone    : std_logic;
    signal rdn         : std_logic;
    signal ready       : std_logic;
    signal resetn      : std_logic;
    signal sdram_a     : std_logic_vector(11 downto 0);
    signal sdram_ba    : std_logic_vector(1 downto 0);
    signal sdram_cas_n : std_logic;
    signal sdram_cke   : std_logic;
    signal sdram_clk   : std_logic;
    signal sdram_cs_n  : std_logic;
    signal sdram_dq    : std_logic_vector(31 downto 0);
    signal sdram_dqm   : std_logic_vector(3 downto 0);
    signal sdram_ras_n : std_logic;
    signal sdram_we_n  : std_logic;
    signal wrn         : std_logic;


    -- Component Declarations
    component mt48lc4m32b2
    generic (
        addr_bits : integer := 12;
        data_bits : integer := 32;
        col_bits  : integer := 8;
        mem_sizes : integer := 1048575;
        tAC       : real    := 5.5;
        tHZ       : real    := 5.5;
        tOH       : real    := 2.0;
        tMRD      : real    := 2.0;
        tRAS      : real    := 42.0;
        tRC       : real    := 60.0;
        tRCD      : real    := 18.0;
        tRFC      : real    := 60.0;
        tRP       : real    := 18.0;
        tRRD      : real    := 12.0;
        tWRa      : real    := 6.0;
        tWRm      : real    := 12.0
    );
    port (
        Addr  : in     std_logic_vector (addr_bits - 1 downto 0);
        Ba    : in     std_logic_vector (1 downto 0);
        Cas_n : in     std_logic;
        Cke   : in     std_logic;
        Clk   : in     std_logic;
        Cs_n  : in     std_logic;
        Dqm   : in     std_logic_vector (3 downto 0);
        Ras_n : in     std_logic;
        We_n  : in     std_logic;
        Dq    : inout  std_logic_vector (data_bits - 1 downto 0)
    );
    end component;
    component sdram_ctrl
    port (
        abus        : in     std_logic_vector (23 downto 0);
        clk         : in     std_logic ;
        csn         : in     std_logic ;
        dbus_in     : in     std_logic_vector (7 downto 0);
        rdn         : in     std_logic ;
        resetn      : in     std_logic ;
        sdram_clk   : in     std_logic ;
        wrn         : in     std_logic ;
        dbus_out    : out    std_logic_vector (7 downto 0);
        initdone    : out    std_logic ;
        ready       : out    std_logic ;
        sdram_a     : out    std_logic_vector (11 downto 0);
        sdram_ba    : out    std_logic_vector (1 downto 0);
        sdram_cas_n : out    std_logic ;
        sdram_cke   : out    std_logic ;
        sdram_cs_n  : out    std_logic ;
        sdram_dqm   : out    std_logic_vector (3 downto 0);
        sdram_ras_n : out    std_logic ;
        sdram_we_n  : out    std_logic ;
        sdram_dq    : inout  std_logic_vector (31 downto 0)
    );
    end component;
    component sdram_ctrl_tester
    port (
        dbus_out  : in     std_logic_vector (7 downto 0);
        initdone  : in     std_logic ;
        ready     : in     std_logic ;
        abus      : out    std_logic_vector (23 downto 0);
        ale       : buffer std_logic ;
        clk       : buffer std_logic ;
        csn       : out    std_logic ;
        dbus_in   : out    std_logic_vector (7 downto 0);
        rdn       : out    std_logic ;
        resetn    : buffer std_logic ;
        sdram_clk : out    std_logic ;
        wrn       : out    std_logic 
    );
    end component;

begin

    -- Instance port mappings.
    RAM : mt48lc4m32b2
        generic map (
            addr_bits => 12,
            data_bits => 32,
            col_bits  => 8,
            mem_sizes => 1048575,
            -- // Commands Operation
            tAC       => 17.0,
            tHZ       => 17.0,
            tOH       => 2.5,
            tMRD      => 2.5,            --// 2 Clk Cycles
            tRAS      => 42.0,
            tRC       => 70.0,
            tRCD      => 20.0,
            tRFC      => 70.0,
            tRP       => 20.0,
            tRRD      => 14.0,
            tWRa      => 7.0,            --// A2 Version - Auto precharge mode (1 Clk + 7 ns)
            tWRm      => 14.0            --// A2 Version - Manual precharge mode (14 ns)
        )
        port map (
            Dq    => sdram_dq,
            Addr  => sdram_a,
            Ba    => sdram_ba,
            Clk   => sdram_clk,
            Cke   => sdram_cke,
            Cs_n  => sdram_cs_n,
            Ras_n => sdram_ras_n,
            Cas_n => sdram_cas_n,
            We_n  => sdram_we_n,
            Dqm   => sdram_dqm
        );
    DUT : sdram_ctrl
        port map (
            abus        => abus,
            clk         => clk,
            csn         => csn,
            dbus_in     => dbus_in,
            rdn         => rdn,
            resetn      => resetn,
            sdram_clk   => sdram_clk,
            wrn         => wrn,
            dbus_out    => dbus_out,
            initdone    => initdone,
            ready       => ready,
            sdram_a     => sdram_a,
            sdram_ba    => sdram_ba,
            sdram_cas_n => sdram_cas_n,
            sdram_cke   => sdram_cke,
            sdram_cs_n  => sdram_cs_n,
            sdram_dqm   => sdram_dqm,
            sdram_ras_n => sdram_ras_n,
            sdram_we_n  => sdram_we_n,
            sdram_dq    => sdram_dq
        );
    TST : sdram_ctrl_tester
        port map (
            dbus_out  => dbus_out,
            initdone  => initdone,
            ready     => ready,
            abus      => abus,
            ale       => ale,
            clk       => clk,
            csn       => csn,
            dbus_in   => dbus_in,
            rdn       => rdn,
            resetn    => resetn,
            sdram_clk => sdram_clk,
            wrn       => wrn
        );

end struct;
