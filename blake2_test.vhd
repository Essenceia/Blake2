LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_misc.ALL;
use std.textio.all;
use ieee.std_logic_textio.all;

 
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
    

   -- Inputs
   signal clk     : std_logic := '0';
   signal nreset  : std_logic := '0';
   signal valid_i : std_logic := '0';
   signal data_i  : std_logic_vector(1023 downto 0) := (others => '0');

   -- Outputs
   signal hash_v_o : std_logic;
   signal hash_o   : std_logic_vector(511 downto 0);

   -- Clock period definitions
   constant clk_period : time := 10 ns;

   -- Testbench variables
   -- input test vector for data_i
   file   tb_data_i_file   : text;
   signal tb_data_i_tv     : std_logic_vector(1023 downto 0);
   -- test vector for hash_o
   file   tb_hash_o_file   : text;
   signal tb_hash_o_tv     : std_logic_vector(511 downto 0);
   signal tb_hash_o_ored : std_logic;
   signal tb_data_i_ored : std_logic;
 
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
  --  stim_proc: process
  --  begin		
  --     nreset <= '0';
  --     wait for 16 ns;
  --       	nreset  <= '1';
  --       	valid_i <= '1';
  --       	data_i( 23 downto 0 ) <= x"636261";
  --       	
  --       	wait for clk_period;
  --       	valid_i <= '0';
  --       	data_i <=  (others => 'X');

  --     wait for clk_period*10;

  --     wait;
  --  end process;

   -- test bench specific
   tb_hash_o_ored <= or_reduce(hash_o);
   tb_data_i_ored <= or_reduce(data_i);

   asset_proc : process
   begin
   	wait for clk_period;
	-- TestBench verification 
	
	-- reset X check
	assert not(nreset='X') report "nreset is X" severity failure;
	-- input valid and data X check
	assert ( not( (valid_i = 'X') and (nreset='1') )) 
	report "input valid is X" severity failure;
	assert ( not((valid_i = '1')and (tb_data_i_ored='X') and (nreset='1') ))
	report "input data contrains X on valid" severity failure;

	-- Design verification

	-- output valid signal should never be X, with the expection of reset
   	assert( not((hash_v_o = 'X' )and (nreset = '1')) ) 
	report "output valid is X" severity failure;
	-- output data should never contrain and X's when output valid is 1
	-- with the expection of reset
	assert ( not((hash_v_o = '1')and (tb_hash_o_ored='X') and (nreset='1') ))
	report "output data contrains X on valid" severity failure;
   end process;

   -- test vector checking : same output as blake2's c implementaion
   tv_proc : process
	variable tb_db_loop : std_logic;
   	variable tb_data_i_line : line;
   	variable tb_hash_o_line : line;
   	variable tb_data_i_line_vec : std_logic_vector(1023 downto 0);
   	variable tb_hash_o_line_vec : std_logic_vector(511 downto 0);

	begin
	-- file location is relative
   	-- open files containing test vectors, different files for input/output
	file_open( tb_data_i_file, "test_vector/b_data_i.txt", read_mode);
   	file_open( tb_hash_o_file, "test_vector/b_hash_o.txt", read_mode);
	nreset <= '0';
	wait for 16 ns;
		nreset  <= '1';
	-- tb_data_i and tb_hash_o files have the same number of lines
	while not endfile( tb_data_i_file ) loop
		tb_db_loop := '0';
		-- real file content line by line into a vector
		readline( tb_data_i_file, tb_data_i_line);
		readline( tb_hash_o_file, tb_hash_o_line);
		read(tb_data_i_line, tb_data_i_line_vec);
		read(tb_hash_o_line, tb_hash_o_line_vec);
			
		-- used for testing purposes
		tb_data_i_tv <= tb_data_i_line_vec;
		-- write to input
		-- data_i <= tb_data_i_line_vec;
		-- debug : TODO remove 
		data_i <= ( others => '0' );	
	
		-- used for testing purposes
		tb_hash_o_tv <= tb_hash_o_line_vec;
		
		valid_i <= '1';		
	
		wait for clk_period;
		
		valid_i <= '0';
		data_i <= ( others => 'X' );
		-- wait for module to produce valid output
		while not ( hash_v_o = '1' ) loop
			tb_db_loop := '1';
			wait for clk_period;
		end loop;
		-- test if module output matches test vector expected output
		
		wait for clk_period;
	end loop;
	-- close files
	file_close( tb_data_i_file);
	wait;
  end process;	

END;
