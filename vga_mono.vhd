library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity vga_mono is
	port (
		pR		: out std_logic;
		pG		: out std_logic;
		pB		: out std_logic;
		pI		: out std_logic;
		pHSYNC 	: out std_logic;
		pVSYNC	: out std_logic;
		
		pVaddr	: out std_logic_vector(14 downto 0);
		pVdata	: inout std_logic_vector(7 downto 0);
		pVwrite	: out std_logic;
		pVenable : out std_logic;
		
		pAaddr	: in std_logic_vector(15 downto 0);
		pAdata	: in std_logic_vector(7 downto 0);
		pArw	: in std_logic;
		pAq3	: in std_logic;
		pAphi0	: in std_logic;
		
		reset 	: in std_logic;
		clk		: in std_logic
	);
end vga_mono;

architecture RTL of vga_mono is

	signal hcount : std_logic_vector(9 downto 0);
	signal vcount : std_logic_vector(9 downto 0);

	signal vga_out : std_logic;

	signal vram_col : std_logic_vector(5 downto 0);
	signal vram_row : std_logic_vector(8 downto 0);
	signal vreg : std_logic_vector(7 downto 0);	
	signal vram_addr : std_logic_vector(14 downto 0);
	signal vram_write : std_logic_vector(2 downto 0);

	signal apple_addr : std_logic_vector(15 downto 0);
	signal apple_data : std_logic_vector(7 downto 0);
	signal apple_write : std_logic;
	
	constant ACTIVE_PIXEL : integer := 640;
	constant ACTIVE_LINE  : integer := 480;

	constant SCREEN_PIXEL : integer := 512;
	constant SCREEN_LINE  : integer := 342;
	constant BORDER_PIXEL : integer := (ACTIVE_PIXEL - SCREEN_PIXEL) / 2;
	constant BORDER_LINE  : integer := (ACTIVE_LINE - SCREEN_LINE) / 2;

	constant FPORCH_PIXEL : integer := SCREEN_PIXEL + BORDER_PIXEL+ 16;
	constant SYNC_PIXEL   : integer := FPORCH_PIXEL + 96;
	constant BPORCH_PIXEL : integer := SYNC_PIXEL + 48 + BORDER_PIXEL;
	
	constant FPORCH_LINE  : integer := SCREEN_LINE + BORDER_LINE + 10;
	constant SYNC_LINE    : integer := FPORCH_LINE + 2;
	constant BPORCH_LINE  : integer := SYNC_LINE + 33 + BORDER_LINE;

begin
	pR <= vga_out;
	pG <= vga_out;
	pB <= vga_out;
	pI <= vga_out;
	pVenable <= '0';
	
process(pAq3)
begin
	if (pAq3'event and pAq3 = '0' and pAphi0 = '1') then
		apple_addr <= pAaddr - X"2000";
		apple_data <= pAdata;
		apple_write <= not pArw;
	end if;
end process;

process(clk, reset)
begin
	if (reset = '0') then
		vram_write <= "000";
		pVwrite <= '1';
		pVdata <= (others => 'Z');
	elsif (clk'event and clk = '0') then
		if (hcount(2 downto 0) = "000") then
			vreg <= pVdata;
		else
			vreg <= vreg(6 downto 0) & '0';
		end if;
		if (pAphi0 = '1' and vram_write <= "100") then
			vram_write <= "000";
		end if;
		if (hcount(2 downto 0) = "001") then
			if (pAphi0 = '0' and apple_write = '1' and 
				apple_addr(15) = '0' and vram_write = "000") then
				vram_write <= "001";
			end if;
			pVaddr <= apple_addr(14 downto 0);
		end if;
		if (vram_write = "001") then -- hcount(2 downto 0) = "010"
			pVwrite <= '0';
			vram_write <= "010";
		end if;
		if (vram_write = "010") then -- hcount(2 downto 0) = "011"
			pVdata <= apple_data;
			vram_write <= "011";
		end if;
		if (vram_write = "011") then -- hcount(2 downto 0) = "100"
			pVdata <= (others => 'Z');
			pVwrite <= '1';
			vram_write <= "100";
		end if;
		if (hcount(2 downto 0) = "110") then
			if (hcount > SCREEN_PIXEL) then
				vram_col <= (others => '0');
			end if;
			vram_row <= vcount(8 downto 0);
		end if;
		if (hcount(2 downto 0) = "111") then
			pVaddr <= vram_row & vram_col;
			vram_col <= vram_col + 1;
		end if;
	end if;
end process;

process(clk, reset)
begin
	if (reset = '0') then
		hcount <= (others => '0');
		vcount <= (others => '0');
		pHSYNC <= '1';
		pVSYNC <= '1';
	elsif clk'event and clk = '1' then
		if (conv_integer(hcount) = FPORCH_PIXEL) then
			if (conv_integer(vcount) = FPORCH_LINE) then
				pVSYNC <= '0';
			elsif (conv_integer(vcount) = SYNC_LINE) then
				pVSYNC <= '1';
			end if;
			if (conv_integer(vcount) = (BPORCH_LINE - 1)) then
				vcount <= (others => '0');	
			else
				vcount <= vcount + 1;
			end if;
		end if;
		
		if (conv_integer(hcount) = (BPORCH_PIXEL - 1)) then
			hcount <= (others => '0');
		else
			hcount <= hcount + 1;
		end if;
		
		case (conv_integer(hcount)) is
			when FPORCH_PIXEL => pHSYNC <= '0';
			when SYNC_PIXEL => pHSYNC <= '1';
			when others => null;
		end case;

		if (conv_integer(vcount) < SCREEN_LINE and
			conv_integer(hcount) < SCREEN_PIXEL) then
			vga_out <= not vreg(7);
		else
			vga_out <= '0';
		end if;
		
	end if;
end process;
	
end RTL;
