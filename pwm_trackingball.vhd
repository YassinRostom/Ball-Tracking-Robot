-- the following vhdl code contains the pulse-width modulation control for each wheel
-- it has six inputs clk, reset, enable, L_R, found and N_F
-- input found indicates whether the ball is within the camera frame or not
-- input L_R makes the buggy move either left or right depending on the position of the ball in the camera frame
-- input N_F sets the buggy speed depending on how far the ball is from the buggy
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_trackingball is

	generic (
		NSTATES : natural := 100								-- generic which specifies variable range
	);

	port (
		--INPUTS
		clk	  	: in std_logic;								-- 10kHz clock input
		reset	  	: in std_logic;								-- reset button input				
		enable  	: in std_logic;								--enable input
		found	 	: in std_logic;								--Found Ball camera input
		L_R	  	: in std_logic_vector (2 downto 0);		--Left and Right camera input
		N_F 		: in std_logic_vector (1 downto 0);		--Near and Far camera input
		
		--OUTPUTS
		pwmA  : out std_logic;									--Motor A pwm output
		pwmB  : out std_logic									--Motor B pwm output
	);

end entity;

architecture pwm_trackingball_vl of pwm_trackingball is
		signal DUTY_A : natural range 0 to NSTATES;				-- signal Duty_A of data type natural		
		signal DUTY_B : natural range 0 to NSTATES;				-- signal Duty_B of data type natural
		signal Middle : std_logic;										-- signal Middle of data type std_logic
begin
	process (clk, reset,enable)										-- sensitivity list contains clk, reset and enable
		variable count : natural range 0 to NSTATES;				-- variable count of data type natural

	begin
		if reset = '1' or enable = '0' then 						-- when reset input is high or enable input is low
			count := 0;														-- reset count to 0
			pwmA <= '0';													-- reset pwm for wheel A to 0
			pwmB <= '0';													-- reset pwm for wheel B to 0
		elsif rising_edge(clk) then									-- if there is a rising edge on the clk input
			count := count + 1;											-- increment count by 1
			if count = NSTATES then										-- if count equals 100
				count := 0;													-- reset count to 0
			end if;
			
			if (count < (NSTATES-DUTY_A)) then						-- sets pwm for wheel A
				pwmA <= '0';
			else	
				pwmA <= '1';
			end if;
			if (count < (NSTATES-DUTY_B)) then						-- sets pwm for wheel B
				pwmB <= '0';
			else	
				pwmB <= '1';
			end if;
		end if;
	end process;
 
	process(L_R,found,Middle,N_F)										-- sensitivity list contains L_R, found, Middle amd N_F
	begin
	if ( found = '0' ) then											  	--when found equals 0
		case (L_R) is
			when "000"|"001"|"010"|"011" => 							--Set the buggy to rotate clockwise to search for the ball
				DUTY_A <= 70;
				DUTY_B <= 0;
			when "100"|"101"|"110"|"111" =>							--Set the buggy to rotate anti-clockwise to search for the ball
				DUTY_A <= 0;
				DUTY_B <= 70;
		end case;
	else	
		case L_R is
			when "000" =>															--Sets the buggy to move to the very right to dribble the ball						
				DUTY_A <= 100;
				DUTY_B <= 50;
				Middle<='0';
			when "001" =>															--Sets the buggy to move to the right to dribble the ball
				DUTY_A <= 80;
				DUTY_B <= 40;
				Middle<='0';
			when "010" =>															--Sets the buggy to move forward to dribble the ball
				Middle<='1';
			when "011" =>															--Sets the buggy to move forward to dribble the ball
				Middle<='1';
			when "100" =>															--Sets the buggy to move forward to dribble the ball
				Middle<='1';
			when "101" =>															--Sets the buggy to move forward to dribble the ball
				Middle<='1';
			when "110" =>															--Sets the buggy to move to the left to dribble the ball
				DUTY_A <= 40;
				DUTY_B <= 80;
				Middle<='0';
			when "111" =>															--Sets the buggy to move to the very left to dribble the ball
				DUTY_A <= 50;
				DUTY_B <=100;
				Middle<='0';
		end case;
		
	if ( Middle = '1' ) then											--if the ball is in the middle of the FOV
		case N_F is
			when "00" =>													--when the ball is very near set both wheels Duty cycle to 50%
				DUTY_A <= 50;
				DUTY_B <= 50;
			when "01" =>													--when the ball is near set both wheels Duty cycle to 60%
				DUTY_A <= 60;
				DUTY_B <= 60;
			when "10" =>													--when the ball is far set both wheels Duty cycle to 80%
				DUTY_A <= 80;
				DUTY_B <= 80;
			when "11" =>													--when the ball is very far set both wheels Duty cycle to 100%
				DUTY_A <= 100;
				DUTY_B <= 100;
		end case;
	end if;
	
	end if;
	end process;
end pwm_trackingball_vl;

