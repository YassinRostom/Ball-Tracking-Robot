LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY ColourTracker IS
  
   PORT( 
      --INPUTS 
      clk    : IN     std_logic;
      rst    : IN     std_logic;
      VSYNC    : IN     std_logic;
		U:in unsigned (7 DOWNTO 0); -- pixel data channels
		V:in unsigned (7 DOWNTO 0);
		Y:in unsigned (7 DOWNTO 0);
		ROW: in unsigned (8 DOWNTO 0); -- counter for rows
		COLUMN: in unsigned (10 DOWNTO 0);  -- counter for columns
		Train		 : IN 	 std_logic; -- true only for training frame
		Accumulate: in std_logic; -- true only for valid ROWS (0-479) of data. 
		Calculate: in std_logic;  -- true for last row in VGA sequence (row 480)
		WinROW: in std_logic; -- true only for central window
		WinCOL: in std_logic; -- true only for central window
		YUVclkEN: in std_logic; -- true at the end of the 4 byte seq. use to clock in all data bytes from camera de-serialiser
      --OUTPUTS
      L_R  : OUT    unsigned (2 DOWNTO 0); -- Left to Right position of CofM
      U_D  : OUT    unsigned (1 DOWNTO 0); -- Y metric depends on camera pose
      N_F  : OUT    unsigned (1 DOWNTO 0); -- Z Distance metric proportional to size of target
		Found: out std_logic; -- indicates a pixel matches the trained colour
		--For testing, can be removed when finished
		testWindow		: OUT	unsigned (11 downto 0);		--Keep for now, show that it goes up to 297h
		Average_U	: OUT unsigned (17 downto 0);	--Test Output
		Average_V	: OUT unsigned (17 downto 0);	--Test Output
		Average_Y	: OUT unsigned (17 downto 0);	--Test Output	
		Centre: OUT unsigned (15 downto 0)	--Test output, remove when finished
  );

-- Declarations

END ColourTracker ;

-- Colour tracker both training and test is similar activities
ARCHITECTURE arc OF ColourTracker IS		
		signal TW: unsigned (11 downto 0);
		signal U_SUM: unsigned (17 downto 0);
		signal Y_SUM: unsigned (17 downto 0);
		signal V_SUM: unsigned (17 downto 0);
		signal AV_U: unsigned (17 downto 0);
		signal AV_V: unsigned (17 downto 0);
		signal AV_Y: unsigned (17 downto 0);
begin
	

	pTrain : process(rst, VSYNC, Accumulate, WinROW, WinCOL, Train, YUVclkEN, Calculate) is				
	begin
		if (rst = '1') then	--Asynchronous reset on reset line or end of frame VSYNC - Test required
			TW <= "000000000000";	--Reset the testWindow variable to 0
			U_SUM <= "000000000000000000";	--U channel SUM
			V_SUM <= "000000000000000000";	--V channel SUM
			Y_SUM <= "000000000000000000";	--Y channel SUM
			Average_U <= "000000000000000000";
			Average_V <= "000000000000000000";
			Average_Y <= "000000000000000000";
		elsif (VSYNC = '1') then	--Stay reset for whole VSYNC?
			TW <= "000000000000";
		elsif(Train = '1' and WinCOL = '1' and WinROW = '1' and Accumulate = '1') then
			if (falling_edge(YUVclkEN)) then	--conditions required to train a colour
				TW <= TW + 1;	--Test to prove functionality of test window
				U_SUM <= U_SUM + U;	--Accumulate the values of U
				V_SUM <= V_SUM + V;	--Accumulate the values of V
				Y_SUM <= Y_SUM + Y;	--Accumulate the values of Y
			end if;
		elsif (Train = '1' and rising_edge(Calculate)) then
			AV_U <= (U_SUM/663);	--find the average by dividing by 51*13 pixels
			AV_V <= (V_SUM/663);	--find the average by dividing by 51*13 pixels
			AV_Y <= (Y_SUM/663);	--find the average by dividing by 51*13 pixels
			Average_U <= AV_U;
			Average_V <= AV_V;
			Average_Y <= AV_Y;
		end if;	
	end process pTrain;
	testWindow <= TW;

	
	--Process to calculate the centre of mass
	
	pCOM: process(rst, VSYNC, YUVclkEN, Calculate, Train, Accumulate) is
		variable pixelsum: unsigned (15 downto 0);
		variable foundcount : unsigned (18 downto 0);
		variable xCentre: unsigned (15 downto 0);
	begin
		if (rst = '1' or VSYNC = '1') then
			foundcount := "0000000000000000000"; 
			pixelsum := "0000000000000000";
			xCentre := "0000000000000000";
		elsif (Train = '0' and Calculate = '0' and Accumulate = '1') then	
			if (falling_edge(YUVclkEN)) then
				--Sum the column number of each pixel found to be the correct colour
				--increment a found counter
				if (U < AV_U + 2 and U > AV_U - 2 and Y < AV_Y + 4 and Y > AV_Y - 4 and V < AV_V + 2 and V > AV_V - 2) then
					foundcount := foundcount + 1;
					pixelsum := pixelsum + COLUMN;
				end if;
			end if;
		--Calculate COM if the ball is found, else state not found
		elsif (Train = '0' and rising_edge(Calculate)) then
			if (foundcount > 5) then
				Found <= '1';
				xCentre := (pixelsum/foundcount);
				Centre <= xCentre;
			else	
				Found <= '0';
			end if;
		end if;
	end process pCOM;
	
end architecture;