-------------------------------------------------------------------------------
-- SDRAM Controller core                                                     --
-------------------------------------------------------------------------------
-- Project       : SDRAM                                                     --
-- Unit          : Testbench Tester Module                                   --
-- Library       : sdram                                                     --
--                                                                           --
-- Version       : 0.1   18/07/07                                            --
--               : 0.2   03/11/22  Changed assert failure with STOP(0)       --
-------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.NUMERIC_STD.all;

LIBRARY std;
USE std.TEXTIO.all;

USE work.sdram_pack.all;
USE work.utils.all;

library std;
use std.env.all;

ENTITY sdram_ctrl_tester IS
   PORT( 
      dbus_out  : IN     std_logic_vector (7 DOWNTO 0);
      initdone  : IN     std_logic;
      ready     : IN     std_logic;
      abus      : OUT    std_logic_vector (23 DOWNTO 0);
      ale       : BUFFER std_logic;
      clk       : BUFFER std_logic;
      csn       : OUT    std_logic;
      dbus_in   : OUT    std_logic_vector (7 DOWNTO 0);
      rdn       : OUT    std_logic;
      resetn    : BUFFER std_logic;
      sdram_clk : OUT    std_logic;
      wrn       : OUT    std_logic
   );
END sdram_ctrl_tester ;

ARCHITECTURE behav OF sdram_ctrl_tester IS

COMPONENT random
   PORT (
      clk    : IN     std_logic;
      enable : IN     std_logic;
      resetn : IN     std_logic;
      dOut   : OUT    std_logic_vector(63 downto 0)
   );
END COMPONENT;


signal clk_s  : std_logic:='0';
signal data_s : std_logic_vector(7 downto 0);
signal wdata_s : std_logic_vector(7 downto 0);
signal abus_s : std_logic_vector(23 downto 0);

signal addrcnt_s: unsigned(31 downto 0):=X"00000000";
signal dOut     : std_logic_vector(63 downto 0);
signal ranout_s : std_logic_vector(23 downto 0);
signal enable_s : std_logic;

signal fail_s : integer:=0;

BEGIN
    

    RNG1 : random
      PORT MAP (clk    => clk,
                enable => enable_s,
                resetn => resetn,
                dOut   => dOut);

    process(clk)
        begin
            if rising_edge(clk) then
                if ale='1' then
                    ranout_s<=dOut(23 downto 0);
                end if;
            end if;
    end process;


    clk_s <= not clk_s after (CLK_PERIOD/2)* 1 ns;      
    clk <= clk_s;
    sdram_clk <= NOT clk_s;         -- Use PLL to create 180deg clock, note delta delay between clocks

    process
        variable L   : line;

        procedure wrmem(                            -- write to memory   
            signal addr_p : in std_logic_vector(23 downto 0);-- Port Address
            signal dbus_p : in std_logic_vector(7 downto 0)) is 
            begin 
                --wait until rising_edge(clk_s);        -- Start of T1
                wait for 3 ns;
                ale <= '1';
                wait for 3 ns;
                --abus <= addr_p;

                wait until rising_edge(clk_s);      -- Start of T2
                wait for 2 ns;
                abus <= addr_p;
                wait for 1 ns;
                ale  <= '0';
                wait for 2 ns;
                csn  <= '0';

                wait until rising_edge(clk_s);      -- Start of T3
                wait for 3 ns;
                wrn  <= '0';
                wait for 5 ns;
                dbus_in <= dbus_p;                  -- write data

                wait until rising_edge(clk_s);      -- Start of T4

                while ready='0' loop 
                    wait until rising_edge(clk_s);  -- Start TW             
                end loop;

                wait until rising_edge(clk_s);      -- End of T4
                wait for 2 ns;
                --abus  <= (others => '1');
                csn  <= '1';
                wrn  <= '1';
                wait for 2 ns;
                dbus_in <= (others=>'Z');           -- Z value for debug only
        end wrmem;

        procedure rdmem(                            -- Read from memory   
            signal addr_p : in std_logic_vector(23 downto 0);-- Port Address
            signal dbus_p : out std_logic_vector(7 downto 0)) is 
            begin 
                --wait until rising_edge(clk_s);        -- Start of T1
                wait for 3 ns;
                ale <= '1';
                --wait for 3 ns;
                --abus <= addr_p;

                wait until rising_edge(clk_s);      -- Start of T2
                wait for 2 ns;
                abus <= addr_p;
                wait for 1 ns;
                ale  <= '0';
                wait for 2 ns;
                csn  <= '0';
                rdn  <= '0';

                
                wait until rising_edge(clk_s);      -- Start of T3
                
                wait until rising_edge(clk_s);      -- Start of T4

                while ready='0' loop 
                    wait until rising_edge(clk_s);  -- Start TW             
                end loop;


                wait until falling_edge(clk_s);     -- End of T4
                wait for ((CLK_PERIOD/2)-1)* 1 ns;
                dbus_p<= dbus_out;
                wait until rising_edge(clk_s);      -- End of T4
                wait for 2 ns;
                --abus <= (others => '1');
                csn  <= '1';
                rdn  <= '1';
        end rdmem;


        begin

            dbus_in  <= (others => 'Z');
            abus     <= (others => '1');
            data_s   <= (others => 'H');
            rdn      <= '1';
            wrn      <= '1';
            csn      <= '1';
            ale      <= '0';
            resetn   <= '0';

            wait for 100 ns;
            resetn   <= '1';
            wait for 100 ns;

            wait until rising_edge(initdone);


            ---------------------------------------------------------------------------
            -- Simple Read/Write Test to the same row
            ---------------------------------------------------------------------------
            write(L,string'("------- Read/Write to the same row --------"));   
            writeline(output,L);

            wait for 200 ns;

            addrcnt_s <= X"00000000";
            wait for 0 ns;
            for i in 0 to 255 loop
                abus_s <= std_logic_vector(addrcnt_s(23 downto 0));                     
                data_s    <= std_logic_vector(addrcnt_s(7 downto 0));            
                wrmem(abus_s,data_s);
                addrcnt_s <= addrcnt_s+1;
                wait for 0 ns;
            end loop;
            
            addrcnt_s <= X"00000000";
            wait for 0 ns;
            for i in 0 to 255 loop
                abus_s <= std_logic_vector(addrcnt_s(23 downto 0));                     
                rdmem(abus_s,data_s);
                if (data_s/=std_logic_vector(addrcnt_s(7 downto 0))) then
                    write(L,string'("Invalid Read "));
                    write(L,std_to_hex(data_s));
                    write(L,string'(", Expected "));
                    write(L,std_to_hex(std_logic_vector(addrcnt_s(7 downto 0))));
                    writeline(output,L);
                    fail_s<=1;
                    assert false report "Read/Write to the same row test Failed" severity failure;
                end if;
                addrcnt_s <= addrcnt_s+1;
                wait for 0 ns;
            end loop;

            wait for 200 ns;

            ---------------------------------------------------------------------------
            -- Simple Read/Write Test to the different row
            ---------------------------------------------------------------------------
            write(L,string'("------- Read/Write to a different row/bank --------"));   
            writeline(output,L);

            addrcnt_s <= X"00000000";
            wait for 0 ns;
            for i in 0 to 255 loop
                abus_s <= std_logic_vector(addrcnt_s(7 downto 6)) & "0000000000" &
                          std_logic_vector(addrcnt_s(5 downto 2)) & "000000" &
                          std_logic_vector(addrcnt_s(1 downto 0));                    
                data_s    <= std_logic_vector(addrcnt_s(7 downto 0));            
                wrmem(abus_s,data_s);
                addrcnt_s <= addrcnt_s+1;
                wait for 0 ns;
            end loop;
            
            addrcnt_s <= X"00000000";
            wait for 0 ns;
            for i in 0 to 255 loop
                abus_s <= std_logic_vector(addrcnt_s(7 downto 6)) & "0000000000" &
                          std_logic_vector(addrcnt_s(5 downto 2)) & "000000" &
                          std_logic_vector(addrcnt_s(1 downto 0));                    
                rdmem(abus_s,data_s);
                if (data_s/=std_logic_vector(addrcnt_s(7 downto 0))) then
                    write(L,string'("Invalid Read "));
                    write(L,std_to_hex(data_s));
                    write(L,string'(", Expected "));
                    write(L,std_to_hex(std_logic_vector(addrcnt_s(7 downto 0))));
                    writeline(output,L);
                    fail_s<=1;
                    assert false report "Read/Write to a different row test Failed" severity failure;
                end if;
                addrcnt_s <= addrcnt_s+1;
                wait for 0 ns;
            end loop;


            ---------------------------------------------------------------------------
            -- Read the original location again
            -- Assume refresh is modeled correctly
            ---------------------------------------------------------------------------
            addrcnt_s <= X"00000000";
            wait for 0 ns;
            for i in 0 to 255 loop
                abus_s <= std_logic_vector(addrcnt_s(23 downto 0));                     
                rdmem(abus_s,data_s);
                if (data_s/=std_logic_vector(addrcnt_s(7 downto 0))) then
                    write(L,string'("Invalid Read "));
                    write(L,std_to_hex(data_s));
                    write(L,string'(", Expected "));
                    write(L,std_to_hex(std_logic_vector(addrcnt_s(7 downto 0))));
                    writeline(output,L);
                    fail_s<=1;
                    assert false report "Read/Write previous write Failed" severity failure;
                end if;
                addrcnt_s <= addrcnt_s+1;
                wait for 0 ns;
            end loop;

            wait for 200 ns;

            ---------------------------------------------------------------------------
            -- Random R/W
            ---------------------------------------------------------------------------
            write(L,string'("------- Random R/W --------"));   
            writeline(output,L);
            enable_s<='1';

            wait for 200 ns;

            for i in 0 to 65535 loop
                enable_s<='0';
                wait for 0 ns;
                abus_s  <= ranout_s;                     
                wdata_s  <= std_logic_vector(ranout_s(7 downto 0)); 
                wait for 0 ns;           
                wrmem(abus_s,wdata_s);
                enable_s<='1';
                wait for 0 ns;
                rdmem(abus_s,data_s);
                if (data_s/=wdata_s) then
                    write(L,string'("Invalid Read "));
                    write(L,std_to_hex(data_s));
                    write(L,string'(", Expected "));
                    write(L,std_to_hex(wdata_s));
                    writeline(output,L);
                    fail_s<=1;
                    assert false report "Random Read/Write test Failed" severity failure;
                end if;
            end loop;

            ---------------------------------------------------------------------------
            -- Fill memory
            ---------------------------------------------------------------------------
            write(L,string'("------- Write Pattern to memory--------"));   
            writeline(output,L);


            addrcnt_s <= X"00000000";
            wait for 0 ns;
            for i in 0 to 65535 loop
                abus_s <= std_logic_vector(addrcnt_s(23 downto 2))&"00";                     
                data_s  <= std_logic_vector(addrcnt_s(7 downto 0));            
                wrmem(abus_s,data_s);

                abus_s <= std_logic_vector(addrcnt_s(23 downto 2))&"01";                                    
                data_s  <= std_logic_vector(addrcnt_s(15 downto 8));            
                wrmem(abus_s,data_s);
                
                abus_s <= std_logic_vector(addrcnt_s(23 downto 2))&"10";                     
                data_s  <= std_logic_vector(addrcnt_s(23 downto 16));            
                wrmem(abus_s,data_s);
                
                abus_s <= std_logic_vector(addrcnt_s(23 downto 2))&"11";                     
                data_s  <= std_logic_vector(addrcnt_s(31 downto 24));            
                wrmem(abus_s,data_s);

                addrcnt_s <= addrcnt_s+4;
                wait for 0 ns;
            end loop;

            write(L,string'("------- Read Pattern from memory--------"));   
            writeline(output,L);

            addrcnt_s <= X"00000000";
            wait for 0 ns;
            for i in 0 to 65535 loop
                abus_s <= std_logic_vector(addrcnt_s(23 downto 2))&"00";                     
                rdmem(abus_s,data_s);
                assert (data_s=std_logic_vector(addrcnt_s(7 downto 0))) report "Read pattern B0 Failed" severity failure;
                
                abus_s <= std_logic_vector(addrcnt_s(23 downto 2))&"01";                     
                rdmem(abus_s,data_s);
                assert (data_s=std_logic_vector(addrcnt_s(15 downto 8))) report "Read pattern B1 Failed" severity failure;

                abus_s <= std_logic_vector(addrcnt_s(23 downto 2))&"10";                     
                rdmem(abus_s,data_s);
                assert (data_s=std_logic_vector(addrcnt_s(23 downto 16))) report "Read pattern B2 Failed" severity failure;

                abus_s <= std_logic_vector(addrcnt_s(23 downto 2))&"11";                     
                rdmem(abus_s,data_s);
                assert (data_s=std_logic_vector(addrcnt_s(31 downto 24))) report "Read pattern B3 Failed" severity failure;

                addrcnt_s <= addrcnt_s+4;
                wait for 0 ns;
            end loop;

            if (fail_s=1) then				
                report "************ Test Failed ***************";
            else
				report "-------------Test Passed -----------";
            end if;
			STOP(0);

    end process; 
END ARCHITECTURE behav;

