LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY Training IS
  
   PORT( 
      --INPUTS 
      rst    		: IN std_logic;					-- Reset input
      VSYNC    	: IN std_logic;					-- VSYNC at the end of each frame
		U				: in unsigned (7 DOWNTO 0); 	-- pixel data channels
		V				: in unsigned (7 DOWNTO 0);
		Y				: in unsigned (7 DOWNTO 0);
		ROW			: in unsigned (8 DOWNTO 0); 	-- counter for rows
		COLUMN		: in unsigned (10 DOWNTO 0);  -- counter for columns
		Train			: IN std_logic; 					-- true only for training frame
		Accumulate	: in std_logic; 					-- true only for valid ROWS (0-479) of data. 
		Calculate	: in std_logic;  					-- true for last row in VGA sequence (row 480)
		WinROW		: in std_logic; 					-- true only for central window
		WinCOL		: in std_logic; 					-- true only for central window
		YUVclkEN		: in std_logic;					-- true at the end of the 4 byte seq. use to clock in all data bytes from camera de-serialiser
		switch		: in std_logic;					-- DIP switch input for training different colours
		
      --OUTPUTS
		Average_U_follow	: OUT unsigned (17 downto 0);	--Average value of the trained follow colour
		Average_V_follow	: OUT unsigned (17 downto 0);	
		Average_Y_follow	: OUT unsigned (17 downto 0);	
		Average_U_avoid	: OUT unsigned (17 downto 0);	--Average value of the trained avoid colour
		Average_V_avoid	: OUT unsigned (17 downto 0);	
		Average_Y_avoid	: OUT unsigned (17 downto 0);
		Trained				: OUT std_logic					--Output high when both colours are trained
  );

END Training;

ARCHITECTURE arc OF Training IS		
		signal Window				: unsigned (11 downto 0);	--Process window counter
		signal U_SUM			: unsigned (17 downto 0);	--U, Y and V process window accumulators
		signal Y_SUM			: unsigned (17 downto 0);
		signal V_SUM			: unsigned (17 downto 0);
		signal AV_U_follow	: unsigned (17 downto 0);	--Average values for the follow colour
		signal AV_V_follow	: unsigned (17 downto 0);
		signal AV_Y_follow	: unsigned (17 downto 0);
		signal AV_U_avoid		: unsigned (17 downto 0);	--Average values for the avoid colour
		signal AV_V_avoid		: unsigned (17 downto 0);
		signal AV_Y_avoid		: unsigned (17 downto 0);
begin	

	pTrain : process(rst, VSYNC, Accumulate, WinROW, WinCOL, Train, YUVclkEN, Calculate) is	
		variable followTrained	: std_logic;
		variable avoidTrained	: std_logic;
	begin
	
		if (rst = '1') then	--Asynchronous clear all values on reset
			Window 			<= "000000000000";
			U_SUM 			<= "000000000000000000";
			V_SUM 			<= "000000000000000000";
			Y_SUM 			<= "000000000000000000";
			AV_U_follow 	<= "000000000000000000";
			AV_V_follow 	<= "000000000000000000";
			AV_Y_follow 	<= "000000000000000000";
			AV_U_avoid 		<= "000000000000000000";
			AV_V_avoid 		<= "000000000000000000";
			AV_Y_avoid 		<= "000000000000000000";
			followTrained 	:= '0';
			avoidTrained 	:= '0';
			Trained 			<= '0';
			
		elsif (VSYNC = '1') then	--at the end of the frame, clear the process window counter and colour accumulators
			Window 	<= "000000000000";
			U_SUM <= "000000000000000000";	
			V_SUM <= "000000000000000000";	
			Y_SUM <= "000000000000000000";	
			
		elsif(Train = '1' and WinCOL = '1' and WinROW = '1' and Accumulate = '1') then	--conditions required to train a colour
			if (falling_edge(YUVclkEN)) then	
				U_SUM <= U_SUM + U;	--Accumulate the values of U, V and Y
				V_SUM <= V_SUM + V;	
				Y_SUM <= Y_SUM + Y;					
			end if;
			
		elsif (Train = '1' and Calculate = '1') then	--At the end of the frame, calculate the average colour
		
			if (switch = '1') then	--Store as average follow if switch is high
				AV_U_follow 		<= (U_SUM/663);	--find the average by dividing by 51*13 pixels
				AV_V_follow 		<= (V_SUM/663);	
				AV_Y_follow 		<= (Y_SUM/663);	
				Average_U_follow 	<= AV_U_follow;
				Average_V_follow 	<= AV_V_follow;
				Average_Y_follow 	<= AV_Y_follow;
				followTrained 		:= '1';	--state follow colour trained
			else	--Store as average avoid if switch is low
				AV_U_avoid 			<= (U_SUM/663);	--find the average by dividing by 51*13 pixels
				AV_V_avoid 			<= (V_SUM/663);	
				AV_Y_avoid 			<= (Y_SUM/663);	
				Average_U_avoid	<= AV_U_avoid;
				Average_V_avoid 	<= AV_V_avoid;
				Average_Y_avoid 	<= AV_Y_avoid; 
				avoidTrained 		:= '1';	--state avoid colour trained
			end if;					
			
			if (followTrained = '1' and avoidTrained = '1') then	--Output the buggy is trained when both colours are trained
				Trained <= '1';
			end if;
			
		end if;	
	end process pTrain;

end architecture arc;
