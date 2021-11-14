
LIBRARY ieee;
USE ieee.std_logic_1164.all;
-- not both this and below -- USE ieee.std_logic_arith.all;
--use IEEE.numeric_bit.all; -- for integer to bit_vector conversion
use IEEE.numeric_std.all; -- for integer to bit_vector conversion
LIBRARY altera; 
USE altera.altera_primitives_components.all; 


ENTITY PixelExtract IS

	PORT
	(
		Clk		: IN  std_logic;
		Yclk_en	: in std_logic;
		Uclk_en	: in std_logic;
		Y1clk_en	: in std_logic;
		Vclk_en	: in std_logic; -- BGRG pixel seq.
		pixel	 : in  STD_LOGIC_VECTOR (7 downto 0) ; -- the pixels put into their correct colour streams
		U  : out  STD_LOGIC_VECTOR (7 downto 0) ; -- U channel pixels (chrominance)
		Ya  : out  STD_LOGIC_VECTOR (7 downto 0) ; -- Y channel pixels (luminance for U pixel) 
		V  : out  STD_LOGIC_VECTOR (7 downto 0) ; -- V channel pixels (chrominance)
		Yb : out  STD_LOGIC_VECTOR (7 downto 0)  -- Y1 channel pixels (luminance for V pixel) 
	);
END PixelExtract;


-- first register the pixel stream
ARCHITECTURE PixelExtract_v1 OF PixelExtract IS


component lpm_dff_PP1 PORT	(
		clock		: IN STD_LOGIC ;
		data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		enable		: IN STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)	); END component;

begin

U1: lpm_dff_PP1 port map (clk,pixel(7 downto 0), Uclk_en, U (7 downto 0));
U2: lpm_dff_PP1 port map (clk,pixel(7 downto 0), Yclk_en, Ya (7 downto 0));
U3: lpm_dff_PP1 port map (clk,pixel(7 downto 0), Vclk_en, V (7 downto 0));
U4: lpm_dff_PP1 port map (clk,pixel(7 downto 0), Y1clk_en,Yb (7 downto 0));

end PixelExtract_v1;

