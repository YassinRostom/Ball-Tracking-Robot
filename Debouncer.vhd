
LIBRARY ieee;
USE ieee.STD_LOGIC_1164.all;
use IEEE.numeric_std.all; -- for integer to bit_vector conversion


ENTITY debouncer IS
PORT (
  Clk       : IN STD_LOGIC;
  SW        : IN STD_LOGIC;  -- sw input
--  Vsync		: in std_logic;
  SWout     : OUT STD_LOGIC;
  Aclr		: out std_logic
);
END debouncer;

ARCHITECTURE clean_pulse OF debouncer IS
	signal cnt       : natural range 0 to 6;
	signal cnt1       : natural range 0 to 6; -- makes switch momentary action for about 2 seconds
	signal reset : std_logic:='0';
	signal reset1 : std_logic:='0';
	signal q,q1: std_logic;
	signal qout: std_logic;
	signal carry: std_logic;
	signal carry1: std_logic :='1'; -- ovflo from count1 for monostable action on switch input
	signal clr3: std_logic;
	signal SWbar: std_logic;
	component dff port(d,clk,clrn,prn:in std_logic; q:out std_logic);end component;
 	

BEGIN
u1: reset <= SWbar xnor q;
u2: dff port map(SWbar,carry,'1','1',q);
u3: dff port map('1',reset1,clr3,'1',qout); -- was qout, now q1
--u4: dff port map(q1,reset1,clr3,'1',qout); -- PFC 23.06.08 to remove timing QA issue

SWbar <= not SW;
Swout <=  qout; -- was not q;
reset1 <= not q; -- enable 2nd counter
clr3<= carry1 ; -- assume Trained pulse is always longer than a FRAME period*******

---------------------------------------------------------------
  CLOCK: PROCESS (Clk, reset)
  BEGIN
    if reset = '1' then
      cnt <= 0;
    elsif (clk'EVENT and Clk = '1') then
		cnt <= cnt + 1;
    end if;

end process CLOCK;
---------------------------------------------------------------
AclrPULSE: process (cnt,q)
begin
	 if (cnt = 1) and (q='1') then
		Aclr <= '1';
	 else
		Aclr <='0';
	 end if;
end process AclrPULSE;
---------------------------------------------------------------
carryPULSE: process (cnt)
begin
	 if (cnt = 3) then
		carry <= '1';
	 else
		carry <='0';
	
	 end if;
end process carryPULSE;
---------------------------------------------------------------
  CLOCK1: PROCESS (Clk, reset1)
  BEGIN
    if (reset1='0') then
      cnt1 <= 0;
    elsif (clk'EVENT and Clk = '1')  then
		cnt1 <= cnt1 + 1;
		if cnt1 = 4 then
			carry1 <='0';
		else
			carry1 <='1';
		end if;
    end if;
end process CLOCK1;

---------------------------------------------------------------

							
END clean_pulse;