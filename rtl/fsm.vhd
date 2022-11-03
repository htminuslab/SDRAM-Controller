-------------------------------------------------------------------------------
-- SDRAM Controller core                                                     --
-------------------------------------------------------------------------------
-- Project       : SDRAM                                                     --
-- Unit          : State Machine                                             --
-- Library       : sdram                                                     --
--                                                                           --
-- Version       : 0.1   18/07/07                                            --
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.NUMERIC_STD.all;

USE work.sdram_pack.all;

entity fsm is
    port( 
        clk         : in     std_logic;
        rd          : in     std_logic;
        refresh_req : in     std_logic;
        resetn      : in     std_logic;
        same_row    : in     std_logic;
        same_word   : in     std_logic;
        wr          : in     std_logic;
        a10         : out    std_logic;
        cmd         : out    std_logic_vector (3 downto 0);
        initdone    : out    std_logic;
        latch_dqm   : out    std_logic;
        latch_mode  : out    std_logic;
        latch_row   : out    std_logic;
        latch_word  : out    std_logic;
        ready       : out    std_logic;
        rlatch      : out    std_logic);
end fsm ;
 
architecture fsm of fsm is

    -- Architecture Declarations
    signal cnt_100us : integer RANGE 20000 DOWNTO 0;  
    signal cnt_delay : integer RANGE 15 DOWNTO 0;  
    signal pr_read : std_logic;  

    type state_type is (
        sReset,
        sReady,
        sActive,
        sRead,
        sRlatch,
        sRefrsh,
        sWrite,
        sWWait,
        sRNOP,
        sPrCH1,
        sPrCH2,
        sRfNOP,
        sReadB,
        sRDQM,
        sRfAct,
        sinit1,
        spor0,
        sinit2,
        sinit2d,
        sinit3,
        sinit1d,
        sinit3d,
        sinit4,
        sinit4d,
        spor1,
        spor2,
        sidone
    );
 
    -- Declare current and next state signals
    signal current_state : state_type;
    signal next_state : state_type;

    -- Declare any pre-registered internal signals
    signal initdone_cld : std_logic ;

begin

    -----------------------------------------------------------------
    clocked_proc : process ( 
        clk,
        resetn
    )
    -----------------------------------------------------------------
    begin
        if (resetn = '0') then
            current_state <= sReset;
            -- Default Reset Values
            initdone_cld <= '0';
            cnt_100us <= 0;
            cnt_delay <= 0;
            pr_read <= '0';
        elsif (clk'event and clk = '1') then
            current_state <= next_state;

            -- Combined Actions
            case current_state is
                when sRead => 
                    pr_read<='1';
                when sWrite => 
                    pr_read<='0';
                when sRfNOP => 
                    pr_read<='0';
                when sinit1 => 
                    cnt_delay<=tRP_CYCLES;
                when sinit2 => 
                    cnt_delay<=tRFC_CYCLES;
                when sinit2d => 
                    cnt_delay<=cnt_delay-1;
                when sinit3 => 
                    cnt_delay<=tRFC_CYCLES;
                when sinit1d => 
                    cnt_delay<=cnt_delay-1;
                when sinit3d => 
                    cnt_delay<=cnt_delay-1;
                when sinit4 => 
                    cnt_delay<=tMRD_CYCLES;
                    if (tMRD_CYCLES=1) then 
                        initdone_cld<='1';
                    end if;
                when sinit4d => 
                    cnt_delay<=cnt_delay-1;
                    if (cnt_delay=1) then 
                        initdone_cld<='1';
                    end if;
                when spor1 => 
                    cnt_100us<=tPOR_CYCLES;
                when spor2 => 
                    cnt_100us<=cnt_100us-1;
                when others =>
                    null;
            end case;
        end if;
    end process clocked_proc;
 
    -----------------------------------------------------------------
    nextstate_proc : process ( 
        cnt_100us,
        cnt_delay,
        current_state,
        pr_read,
        rd,
        refresh_req,
        same_row,
        same_word,
        wr
    )
    -----------------------------------------------------------------
    begin
        -- Default state assignment
        next_state <= current_state;
        -- Default Assignment
        a10 <= '0';
        cmd <= NOP;
        latch_dqm <= '0';
        latch_mode <= '0';
        latch_row <= '0';
        latch_word <= '0';
        ready <= '1';
        rlatch <= '0';

        -- Combined Actions
        case current_state is
            when sReset => 
                next_state <= spor0;
            when sReady => 
                if (refresh_req='1') then 
                    ready<=NOT(rd OR wr);
                    a10<='1';
                    next_state <= sPrCH2;
                elsif (rd='1'AND same_row='1'
                       AND same_word='1'
                       AND pr_read='1') then 
                    next_state <= sReadB;
                elsif (rd='1'AND same_row='1'
                       AND pr_read='1') then 
                    latch_dqm<='1';
                    next_state <= sRDQM;
                elsif (wr='1' AND 
                       same_row='1') then 
                    latch_dqm<='1';
                    next_state <= sWrite;
                elsif (rd='1' OR wr='1') then 
                    a10<='1';
                    ready<='0';
                    latch_dqm<=rd;
                    next_state <= sPrCH1;
                else
                    next_state <= sReady;
                end if;
            when sActive => 
                cmd<=ACTIVE;
                ready<='0';
                if (wr='1') then 
                    ready<='1';
                    latch_dqm<='1';
                    next_state <= sWrite;
                else
                    latch_dqm<='1';
                    next_state <= sRead;
                end if;
            when sRead => 
                cmd<=READC;
                latch_word<='1';
                ready<='0';
                latch_dqm<='1';
                next_state <= sRlatch;
            when sRlatch => 
                rlatch<='1';
                --latch_dqm<='1';  
                next_state <= sRNOP;
            when sRefrsh => 
                cmd<=AUTO_REFRESH;
                ready<=NOT(rd OR wr);
                next_state <= sRfNOP;
            when sWrite => 
                cmd<=WRITEC;
                next_state <= sWWait;
            when sWWait => 
                if (wr='0') then 
                    next_state <= sReady; 
                else
                    next_state <= sWWait;
                end if;
            when sRNOP => 
                if (rd='0') then 
                    next_state <= sReady;
                else
                    next_state <= sRNOP;
                end if;
            when sPrCH1 => 
                cmd<=PRECHARGE;
                ready<='0';
                latch_row<='1';
                latch_dqm<=rd;
                next_state <= sActive;
            when sPrCH2 => 
                cmd<=PRECHARGE;
                ready<=NOT(rd OR wr);
                next_state <= sRefrsh;
            when sRfNOP => 
                ready<=NOT(rd OR wr);
                if (rd='1' OR 
                    wr='1') then 
                    latch_row<='1';
                    latch_dqm<=rd;
                    next_state <= sActive;
                else
                -- coverage off -item s 1
                    latch_row<='1';
                    next_state <= sRfAct;
                -- coverage on 
                end if;
            when sReadB => 
                if (rd='0') then 
                    next_state <= sReady;
                end if;
            when sRDQM => 
                ready<='0';  
                latch_dqm<='1';
                next_state <= sRead;
            when sRfAct => 
                cmd<=ACTIVE;
                ready<=NOT(rd OR wr);
                next_state <= sReady;
            when sinit1 => 
                cmd<=PRECHARGE;
                if (tRP_CYCLES=1) then 
                    next_state <= sinit2;
                else
                    next_state <= sinit1d;
                end if;
            when spor0 => 
                next_state <= spor1;
            when sinit2 => 
                cmd<=AUTO_REFRESH;
                if (tRFC_CYCLES=1) then 
                    next_state <= sinit3;
                else
                    next_state <= sinit2d;
                end if;
            when sinit2d => 
                if (cnt_delay=1) then 
                    next_state <= sinit3;
                else
                    next_state <= sinit2d;
                end if;
            when sinit3 => 
                cmd<=AUTO_REFRESH;
                if (tRFC_CYCLES=1) then 
                    latch_mode<='1';
                    next_state <= sinit4;
                else
                    next_state <= sinit3d;
                end if;
            when sinit1d => 
                if (cnt_delay=1) then 
                    next_state <= sinit2;
                else
                    next_state <= sinit1d;
                end if;
            when sinit3d => 
                if (cnt_delay=1) then 
                    latch_mode<='1';
                    next_state <= sinit4;
                else
                    next_state <= sinit3d;
                end if;
            when sinit4 =>  
                cmd<=MODE;
                if (tMRD_CYCLES=1) then 
                    next_state <= sidone;
                else
                    next_state <= sinit4d;
                end if;
            when sinit4d =>  
                if (cnt_delay=1) then 
                    next_state <= sidone;
                else
                    next_state <= sinit4d;
                end if;
            when spor1 => 
                next_state <= spor2;
            when spor2 => 
                if (cnt_100us=1) then 
                    a10<='1';  
                    next_state <= sinit1;
                else	
					a10<='1';
                    next_state <= spor2;
                end if;
            when sidone => 
                next_state <= sReady;
            when others =>
                next_state <= sReset;
        end case;
    end process nextstate_proc;
 
    -- Concurrent Statements
    -- Clocked output assignments
    initdone <= initdone_cld;
end fsm;
