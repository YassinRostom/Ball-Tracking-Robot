LIBRARY ieee;
USE ieee.std_logic_1164.all;
use IEEE.numeric_std.all; -- for integer to bit_vector conversion
LIBRARY altera; 
USE altera.altera_primitives_components.all; 


ENTITY SyncProcessor IS
	PORT
	(
		Clk 		 : IN  std_logic;
		Vsync 		 : IN std_logic;
		Href		 : IN std_logic;
		TrainFlag 	 : IN  std_logic; -- from debounced user switch input
		Aclr		 : IN std_logic; -- hold decode of pixel colour 01==red, 10==green, 11==blue
		YUV			 : out unsigned (2 downto 0); -- values R, G and B 4 pixels in a stream 000 is only set during Vsync
		Row			 : out unsigned (8 downto 0); -- 480 == 256+128+64 ie. "111100000"
		Column		 : out unsigned (10 downto 0); -- 640 == 512+128 ie. "1010000000"
		AccumulateSIGNAL : out std_logic; -- is HIGH during hysnc's within a frame, reset by Vsync
		CalculateSIGNAL : out std_logic; -- is HIGH during gap between last hysnc in a frame, reset by Vsync
		FirstROW	: out std_logic; -- true for first row in frame
		LastROW		: out std_logic; -- true for last row in frame
		WindowROW	: out std_logic; -- true for valid ROWs in specified processing window
		WindowCOLUMN: out std_logic;  -- true for valid COLUMNs in specified processing window
		TrainFLAGsynced:out std_logic; -- the user input TrainFLAG now sync'd to one frame only
		YUVclkEN: out std_logic;
		YclkEN: out std_logic;
		UclkEN: out std_logic;
		Y1clkEN: out std_logic;
		VclkEN: out std_logic; -- BGRG pixel seq.
		Framecount: out unsigned (31 downto 0); -- for Colibri frame timing calc.
		Insert:out std_logic; -- insert data into pixel stream PC 16.07.08
		Href_DFF:out std_logic -- delay Href to sync with Calc and Accum
	);
END SyncProcessor;


-- first register the pixel stream
ARCHITECTURE SyncProcessor_v2 OF SyncProcessor IS

	constant VGAmaxROW: natural := 480; -- count from 0
	constant VGAmaxCOLUMN: natural := 640*2; -- 1280 data bytes in a line (UY for pixel N and then VY for pixel N+1)
	
	--##########################################################################################
	-- processing window size
	constant RwinSTARTc: natural	:= (VGAmaxROW/2)-25; -- was -50 but too wide;
	constant RwinENDc: natural	:= (VGAmaxROW/2)+25; --(240+25);
	constant CwinSTARTc: natural	:= ((VGAmaxCOLUMN/2)-25);-- centre of FOV
	constant CwinENDc: natural	:= ((VGAmaxCOLUMN/2)+25); 
	
	--##########################################################################################	
	shared variable FrameCounter: unsigned(31 downto 0) := "00000000000000000000000000000000"; -- counts frames up to limit of integer range
	signal YUV_Cstate, YUV_Nstate: unsigned (2 downto 0); -- natural range 0 to 3; -- was unsigned (2 downto 0); 
	signal RowCounter : natural range 0 to VGAmaxROW; --was unsigned (8 downto 0);
	signal ColumnCounter: natural range 0 to VGAmaxCOLUMN; -- was unsigned (9 downto 0);
	signal LastROWint:  std_logic; -- true for last row in frame
	signal RowCENTRE,ColumnCENTRE: std_logic;
	signal INFrameFLAGint: std_logic; -- '1' for all Href rows in a frame
	signal AccumulateSIGNALint: std_logic; 
	signal CalculateSIGNALint: std_logic; 
	signal GO: std_logic :='1'; -- used to enable the counter, hence cleared to stop it.
	signal STOP: std_logic :='1'; -- used to enable the counter, hence cleared to stop it.
	signal STOPn: std_logic :='0';
	signal TrainFLAGstart,resetFLAG: std_logic; -- sync's start of training with Vsync 
	signal TrainDELAYED, TrainDELAYEDmore: std_logic;
	shared variable InsertData : std_logic;
	
	component dff port(d,clk,clrn,prn:in std_logic; q:out std_logic);end component;

BEGIN
	Row <= to_unsigned(Rowcounter,9); -- was RowCounter ; -- WAS (to_unsigned(Rowcounter,9)); -- convert integer to bit_vector!
	---PC 30.06.07  Column <= to_unsigned(Columncounter,10); -- was ColumnCounter; -- was (to_unsigned(Columncounter,10));
	Column <= to_unsigned(Columncounter,11); -- was ColumnCounter; -- was (to_unsigned(Columncounter,10));
	YUV <= YUV_Cstate; -- was to_unsigned(YUVcounter,3); --- was YUVcounter; 
	LastROW <= LastROWint and Href; -- ensure it does not stay true until next Vsync.
	Insert<=InsertData; --PC 04.08.08
	--STOPo <=STOPn; -- PC 24.06.08 debug
	
	-- now the sequencer for generating the syncronised TrainFLAG to ensure TrainFLAG only lasts one frame
--u1: dff port map(TrainFLAG,Vsync,STOPn,'1',TrainDELAYED);-- train for one frame only
u1: dff port map('1',TrainFLAG,STOPn,'1',TrainDELAYED);-- train for one frame only
--u2: dff port map('1', TrainDELAYED, STOPn,'1',TrainDELAYEDmore);-- train for one frame only
u2: dff port map( TrainDELAYED,Vsync, STOPn,'1',TrainDELAYEDmore);-- train for one frame only
u3: dff port map(TrainDELAYEDmore,Vsync, '1','1',STOP);-- train for one frame only
	STOPn <= NOT(STOP); -- PC made explicit as TranFLAGdsyncd seems not correct!
	TrainFLAGsynced <= TrainDELAYEDmore; -- debug 
u5: dff port map(CalculateSIGNALint,Clk, not(Vsync),'1',CalculateSIGNAL);-- train for one frame only
u6: dff port map(AccumulateSIGNALint,Clk, not(Vsync),'1',AccumulateSIGNAL);-- train for one frame only
	FrameCount <= FrameCounter;
	-- sequential processes belowand Href; -- (not(LastROWint and INFrameFLAGint)); -- 


		---------------------------------------------------------------------------
-- delay Href by 1 clk so that the Accumulate and Calculate signals are in sync
	hrefDFF:	process(clk)
	begin
		if (clk'event and clk= '1') then
			Href_DFF<=Href;
		end if;
	end process hrefDFF;
	

	---------------------------------------------------------------------------
	SYNC: PROCESS (Clk, Href)
	BEGIN
		if 	(Clk'event) and (Clk = '1')  then -- PC 04.08.06 was '1'
			if (Href = '1') then
				ColumnCounter <= ColumnCounter + 1;
	     	elsif (Href = '0')then
				ColumnCounter <= 0; 
			end if;
		end if;
	END PROCESS SYNC ;
	---------------------------------------------------------------------------
	HrefCOUNT: process (Href, Vsync, RowCounter)
	begin
		if (Vsync = '1') then
		    RowCounter <= 0;
		elsif  (Href'event) and (Href = '1') then -- increment row counter every line 
			RowCounter <= RowCounter +1;		
		end if;
	END PROCESS HrefCOUNT;

	-- this is flawed, look at HREF and Accumulate on signaltap. See one clock delay in asserting Accumulate
	-- its not an issue at this point, as the YUV decoder only kicks in for the second 4xdata bytes, thus ignoring the
	-- first two pixels (UY, VY)
	HrefSTM: process (Href, Vsync, RowCounter)
	begin
			case RowCounter is
			when 0 => -- this is between VSYNC & HREF row 1, hence not an active line
				FirstROW <= '0';
				LastROWint <= '0';
				InsertData :='0';
				INframeFLAGint <= '0';
				AccumulateSIGNALint <= '0';
				CalculateSIGNALint <= '0';
			when 1 => -- first active line
				FirstROW <= '1';
				LastROWint <= '0';
				InsertData :='0';
				INframeFLAGint <= '1';
				AccumulateSIGNALint <= '1' and Href;
				CalculateSIGNALint <= '0';
			when (VGAmaxROW-1) =>
				FirstROW <= '0';
				LastROWint <= '1';
				InsertData :='0';
				INframeFLAGint <= '1';
				AccumulateSIGNALint <= '1' and Href;
				CalculateSIGNALint <= '0';
			when VGAmaxROW =>
				FirstROW <= '0';
				LastROWint <= '0';
				InsertData :='1' and Href; -- ensure only line width long PC 07.08.08
				INframeFLAGint <= '0';
				AccumulateSIGNALint <= '0';
				CalculateSIGNALint <= '1' and Href; -- last href ensures Calc signal goes low before Vsync
			when others =>
				FirstROW <= '0';
				LastROWint <= '0';
				InsertData :='0';
				INframeFLAGint <= '1';
				AccumulateSIGNALint <= '1' and Href;
				CalculateSIGNALint <= '0';
			end case;

	end process HrefSTM;
	
	---------------------------------------------------------------------------
	VsyncCOUNT: process (Vsync, Aclr,TrainFlag, ColumnCounter)
	begin
		if (Aclr = '1') then -- PC 25.06.08 clr on Aclr!
			FrameCounter := "00000000000000000000000000000000";
		elsif  (Vsync'event) and (Vsync = '1') then -- increment row counter every line 
			FrameCounter := FrameCounter +1;
		end if;
	end process VsyncCOUNT;

		---------------------------------------------------------------------------

		---------------------------------------------------------------------------
	-- used to output a centre of frame pulse FOR TRAINING
	RowPULSE: process ( Href, RowCounter)
	begin
		if (RowCounter >= RwinSTARTc)and (RowCounter <= RwinENDc) then --and (Href= '1') then --240
			WindowROW <= '1';
		else 
			WindowROW <= '0';
		end if;
	end process RowPULSE;	
	---------------------------------------------------------------------------
	ColumnPULSE: process (ColumnCounter, Href)
	begin
		if (ColumnCounter >= CwinSTARTc) and (ColumnCounter <= CwinENDc) then -- was and (Href = '1') then --1
			WindowCOLUMN <= '1';
		else 
			WindowCOLUMN <= '0';
		end if;
	end process ColumnPULSE;
	---------------------------------------------------------------------------
	-- a way of making a state machine
	---------------------------------------------------------------------------
	YUVCLOCK: process (clk, Href, YUV_Nstate) -- clk pixels on 4th pixel, so they are stable for 4 pixel clks.
	begin
		if (Href='0') then
			YUV_Cstate <="000";
		elsif (clk'event) and (clk = '0') then -- PC 03.07.07 was '0', as pixels change on falling edge, but FSM must change with regstered pixels
			YUV_Cstate<=YUV_Nstate;
		end if;
	end process YUVCLOCK;
	---------------------------------------------------------------------------
	YUVmachine: process (Vsync, YUV_Cstate) -- clk pixels on 4th pixel, so they are stable for 4 pixel clks.
	begin			-- 02.07.07 changed Yclk, Uclk, Vclk, Y1clk etc below to correctly reflect pixel data order in stream from camera.
		case YUV_Cstate is
			when "000" =>
				YUV_Nstate <="001";
				YUVclkEN<= '0';
				VclkEN<='0';
				YclkEN<='0';
				UclkEN<='0';
				Y1clkEN<='0';
			when "001" =>
				YUV_Nstate <="010";
				YUVclkEN<='0' ;
				VclkEN<='0';
				YclkEN<='1';
				UclkEN<='0';
				Y1clkEN<='0';
			when "010" =>
				YUV_Nstate <="011";
				YUVclkEN<='0';
				VclkEN<='1';
				YclkEN<='0';
				UclkEN<='0';
				Y1clkEN<='0';
			when "011" =>
				YUV_Nstate <="100";
				YUVclkEN<='1'; -- last clk en in the sequence, all data channels stable
				VclkEN<='0';
				YclkEN<='0';
				UclkEN<='0';
				Y1clkEN<='1';
			when "100" =>
				YUV_Nstate <="001";
				YUVclkEN<='0';
				VclkEN<='0';
				YclkEN<='0';
				UclkEN<='1';
				Y1clkEN<='0';
			when others =>
				YclkEN<='0';
				VclkEN<='0';
				UclkEN<='0';
				Y1clkEN<='0';
				YUV_Nstate <="001";
				YUVclkEN<='0';
		end case;
	end process YUVmachine;
	---------------------------------------------------------------------------
	
	
END SyncProcessor_v2;