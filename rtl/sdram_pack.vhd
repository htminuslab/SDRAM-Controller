-------------------------------------------------------------------------------
-- SDRAM Controller core                                                     --
-------------------------------------------------------------------------------
-- Project       : SDRAM                                                     --
-- Unit          : Delay/Timing constants                                    --
-- Library       : sdram                                                     --
--                                                                           --
-- Version       : 0.1   18/07/07                                            --
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
USE ieee.NUMERIC_STD.all;
  
package sdram_pack is

    ---------------------------------------------------------------------------
    --
    -- ----------------------------------------------------------
    -- | Reserved | WB | OP Mode | CAS Latency | BT | Burst len |
    -- ----------------------------------------------------------
    -- | 11     10  09  08     07  06   05   04  03  02  01   00
    ---------------------------------------------------------------------------
    constant MODE_WORD   : std_logic_vector(11 downto 0):= "001000010000";

    ---------------------------------------------------------------------------
    -- Values based on Micron MT48LC4M32B2-7 1M*32*4
    -- tRC   >= 70ns (RAS Cycle time)
    -- tRRD  >= 20ns (RAS to RAS Banck activate delay)
    -- tRCD  >= 20ns (Activate to command delay - RAS to CAS delay)
    -- tRAS  >= 50ns (RAS Active time)
    -- tRP   >= 20ns (RAS Precharge time)
    -- tMRD  >= 3 tCK
    -- tREF  <= 64ms (Refresh period for 4096 rows, so 64ms/4096 = 15.625us per row)
    -- tRFC  <= 80ns (Row refresh cycle time)
    ---------------------------------------------------------------------------
  
    constant CLK_PERIOD  : positive := 38;              -- Clock period in ns, 38.76=25.8MHz, round downwards
                                                        -- Minimum clock period is 5ns, for lower values the 
                                                        -- integer ranges need to be updated
    constant tPOR        : positive := 100000;          -- Power Up Init delay of 100us
    constant tRFC        : positive := 70;              -- Auto Refresh Period
    constant tRP         : positive := 20;
    constant tMRD        : positive := 70;              -- Not specified in datasheet???
    constant tRCD        : positive := 20;              -- Active to read/write command delay


    constant tPOR_CYCLES : positive := (tPOR+CLK_PERIOD)/CLK_PERIOD;    -- Rounded up
    constant tRP_CYCLES  : positive := (tRP+CLK_PERIOD) /CLK_PERIOD;    -- Precharge delay
    constant tRFC_CYCLES : positive := (tRFC+CLK_PERIOD)/CLK_PERIOD;    -- Refresh Delay
    constant tMRD_CYCLES : positive := (tMRD+CLK_PERIOD)/CLK_PERIOD;    -- Mode programming delay
    constant tRCD_CYCLES : positive := (tRCD+CLK_PERIOD)/CLK_PERIOD;    -- Active delay

    constant tREF        : positive := 15625;           -- Refresh is required every 15.625us
    --constant tREF        : positive := 4000;          -- *** TEST ONLY **** 
    constant tREF_CYCLES : positive := (tREF-CLK_PERIOD*5)/CLK_PERIOD;  -- 5=FSM delay 

    constant CAS_LATENCY : positive := 1;               -- Requires FSM modification if changed

    -- CS RAS CAS WE
    constant INHIBIT       : std_logic_vector(3 downto 0):="1111";      -- Command Inhibit
    constant NOP           : std_logic_vector(3 downto 0):="0111";      -- No Operation
    constant PRECHARGE     : std_logic_vector(3 downto 0):="0010";      -- Precharge banks
    constant AUTO_REFRESH  : std_logic_vector(3 downto 0):="0001";      
    constant MODE          : std_logic_vector(3 downto 0):="0000";      -- Load Mode Register
    constant ACTIVE        : std_logic_vector(3 downto 0):="0011";      -- Open Row
    constant READC         : std_logic_vector(3 downto 0):="0101";      -- Read Command
    constant WRITEC        : std_logic_vector(3 downto 0):="0100";      -- Write Command

END sdram_pack;
