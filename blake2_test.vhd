LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
 
ENTITY blake2_test IS
END blake2_test;
 
ARCHITECTURE behavior OF blake2_test IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT blake2b_hash512
    PORT(
         clk     : IN  std_logic;
         nreset  : IN  std_logic;
         valid_i : IN  std_logic;
         data_i  : IN  std_logic_vector(1023 downto 0);
         hash_v_o : OUT  std_logic;
         hash_o   : OUT  std_logic_vector(511 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal clk     : std_logic := '0';
   signal nreset  : std_logic := '0';
   signal valid_i : std_logic := '0';
   signal data_i  : std_logic_vector(1023 downto 0) := (others => '0');

   --Outputs
   signal hash_v_o : std_logic;
   signal hash_o   : std_logic_vector(511 downto 0);

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
   -- Instantiate the Unit Under Test (UUT)
   uut: blake2b_hash512
	PORT MAP (
          clk      => clk,
          nreset   => nreset,
          valid_i  => valid_i,
          data_i   => data_i,
          hash_v_o => hash_v_o,
          hash_o   => hash_o
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
		nreset  <= '1';
		valid_i <= '1';
		data_i( 23 downto 0 ) <= x"636261";
		
		wait for clk_period;
		valid_i <= '0';
		data_i <=  (others => 'X');

      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
