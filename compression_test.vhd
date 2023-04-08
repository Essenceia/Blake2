LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY compression_test IS
END compression_test;
 
ARCHITECTURE behavior OF compression_test IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT compression
    PORT(
         clk : IN  std_logic;
         nreset : IN  std_logic;
         valid_i : IN  std_logic;
         h_i : IN  std_logic_vector(511 downto 0);
         m_i : IN  std_logic_vector(1023 downto 0);
         t_i : IN  std_logic_vector(127 downto 0);
         f_i : IN  std_logic;
         h_o : OUT  std_logic_vector(511 downto 0);
         valid_o : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal nreset : std_logic := '0';
   signal valid_i : std_logic := '0';
   signal h_i : std_logic_vector(511 downto 0) := (others => '0');
   signal m_i : std_logic_vector(1023 downto 0) := (others => '0');
   signal t_i : std_logic_vector(127 downto 0) := (others => '0');
   signal f_i : std_logic := '0';

 	--Outputs
   signal h_o : std_logic_vector(511 downto 0);
   signal valid_o : std_logic;

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: compression PORT MAP (
          clk => clk,
          nreset => nreset,
          valid_i => valid_i,
          h_i => h_i,
          m_i => m_i,
          t_i => t_i,
          f_i => f_i,
          h_o => h_o,
          valid_o => valid_o
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
		nreset <= '0';
      wait for 16 ns;
		nreset <= '1';
		valid_i <= '1';
		m_i( 23 downto 0 ) <= x"636261";
		
		wait for clk_period;
		valid_i <= '0';
		m_i <=  (others => 'X');

      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
