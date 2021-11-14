
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use IEEE.numeric_std.all; -- for integer to bit_vector conversion
LIBRARY altera; 
USE altera.altera_primitives_components.all; 


ENTITY Pixel_BUF IS
	PORT
	(
		Clk 		 : IN  std_logic;
		Href		 : in std_logic; -- cameras are sync'd so just choose one source
		CAM_i		 : in unsigned (7 downto 0); -- CAM1 pixels + Href
		Href_DFF	 : out std_logic;
		CAM_o		 : out unsigned (7 downto 0) -- selected stream + Href (bit 8)
	);
END Pixel_BUF;


-- select either camera data from CAM1, or from CAM2 
-- or 
ARCHITECTURE Pixel_BUF_v1 OF Pixel_BUF IS

begin

DFF:	process(clk)
	begin
		if (clk'event and clk= '1') then
			CAM_o(7 downto 0) <= CAM_i(7 downto 0);
			Href_DFF<=Href;
		end if;
	end process DFF;

end Pixel_BUF_v1;

			