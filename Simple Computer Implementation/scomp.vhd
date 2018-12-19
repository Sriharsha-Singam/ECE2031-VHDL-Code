-- SCOMP.vhd
-- Simple Computer Implementation with CALL, RETURN, IN, OUT, and SHIFT functions
-- Sriharsha Singam
-- ECE 2031 L08
-- October 30, 2018
LIBRARY IEEE;
LIBRARY ALTERA_MF;
LIBRARY LPM;

USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE ALTERA_MF.ALTERA_MF_COMPONENTS.ALL;
USE LPM.LPM_COMPONENTS.ALL;

ENTITY SCOMP IS
  PORT(
    CLOCK    : IN    STD_LOGIC;
    RESETN   : IN    STD_LOGIC;
    PC_OUT   : OUT   STD_LOGIC_VECTOR( 9 DOWNTO 0);
    AC_OUT   : OUT   STD_LOGIC_VECTOR(15 DOWNTO 0);
    MDR_OUT  : OUT   STD_LOGIC_VECTOR(15 DOWNTO 0);
    MAR_OUT  : OUT   STD_LOGIC_VECTOR( 9 DOWNTO 0);
    MW_OUT	 : OUT   STD_LOGIC;
    FETCH_OUT: OUT   STD_LOGIC;
    IO_WRITE : OUT   STD_LOGIC;
    IO_CYCLE : OUT   STD_LOGIC;
    IO_ADDR  : OUT   STD_LOGIC_VECTOR( 7 DOWNTO 0);
    IO_DATA  : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
END SCOMP;


ARCHITECTURE a OF SCOMP IS
  TYPE STATE_TYPE IS (
    RESET_PC,
    FETCH,
    DECODE,
    EX_LOAD,
    EX_STORE,
    EX_STORE2,
    EX_ADD,
    EX_JUMP,
    EX_AND,
    EX_SUB,
    EX_JNEG,
    EX_JPOS,
    EX_JZERO,
    EX_OR,
    EX_XOR,
    EX_ADDI,
    EX_SHIFT,
    EX_CALL,
    EX_RETURN,
    EX_IN,
    EX_OUT,
    EX_OUT2
  );

  SIGNAL STATE    : STATE_TYPE;
  SIGNAL AC       : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL IO_IN	  : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL IR       : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL MDR      : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL PC       : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL MEM_ADDR : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL MW       : STD_LOGIC;
  SIGNAL AC_SHIFTED: STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL PC_STACK: STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL IO_WRITE_INT : STD_LOGIC;


  BEGIN
    -- Use altsyncram component for unified program and data memory
    MEMORY : altsyncram
    GENERIC MAP (
    intended_device_family => "Cyclone",
    width_a          => 16,
    widthad_a        => 10,
    numwords_a       => 1024,
    operation_mode   => "SINGLE_PORT",
    outdata_reg_a    => "UNREGISTERED",
    indata_aclr_a    => "NONE",
    wrcontrol_aclr_a => "NONE",
    address_aclr_a   => "NONE",
    outdata_aclr_a   => "NONE",
    init_file        => "LABSTEP6LAB8.mif",
    lpm_hint         => "ENABLE_RUNTIME_MOD=NO",
    lpm_type         => "altsyncram"
    )
    PORT MAP (
    wren_a    => MW,
    clock0    => NOT(CLOCK),
    address_a => MEM_ADDR,
    data_a    => AC,
    q_a       => MDR
    );
    
    -- Use LPN_CLSHIFT function to shift AC
    SHIFTER: LPM_CLSHIFT
    GENERIC MAP(
	   lpm_width	 => 16,
	   lpm_widthdist => 4,
	   lpm_shifttype => "LOGICAL"
    )
    PORT MAP(
	   data 	 => AC,
	   distance  => IR(3 DOWNTO 0),
	   direction => IR(4),
	   result    => AC_SHIFTED
    );

	IO_BUS:	LPM_BUSTRI
	GENERIC MAP(
		lpm_width => 16
	)
	PORT MAP(
		data 	 => AC,
		enabledt => IO_WRITE_INT,
		tridata	 => IO_DATA
	);
    PC_OUT   <= PC;
    MW_OUT	 <= MW;
    AC_OUT   <= AC;
    MDR_OUT  <= MDR;
    MAR_OUT  <= MEM_ADDR;
    IO_ADDR  <= IR(7 DOWNTO 0);

    WITH STATE SELECT
      MEM_ADDR <= PC WHEN FETCH,
                 IR(9 DOWNTO 0) WHEN OTHERS;
                 
    WITH STATE SELECT
		IO_WRITE  <=  '1' WHEN EX_OUT2,
					  '0' WHEN OTHERS;

	WITH STATE SELECT
		IO_CYCLE  <=  '1' WHEN EX_IN,
					  '1' WHEN EX_OUT2,
					  '0' WHEN OTHERS;
					  
	WITH STATE SELECT
		FETCH_OUT <= '1' WHEN FETCH,
					 '0' WHEN OTHERS;
					 
    PROCESS (CLOCK, RESETN)
      BEGIN
        IF (RESETN = '0') THEN          -- Active low, asynchronous reset
          STATE <= RESET_PC;
        ELSIF (RISING_EDGE(CLOCK)) THEN
          CASE STATE IS
            WHEN RESET_PC =>
              MW        <= '0';          -- Clear memory write flag
              PC        <= "0000000000"; -- Reset PC to the beginning of memory, address 0x000
              AC        <= x"0000";      -- Clear AC register
              STATE     <= FETCH;

            WHEN FETCH =>
              MW    <= '0';             -- Clear memory write flag
              IR    <= MDR;             -- Latch instruction into the IR
              PC    <= PC + 1;          -- Increment PC to next instruction address
              STATE <= DECODE;

            WHEN DECODE =>
              CASE IR(15 downto 10) IS
                WHEN "000000" =>       -- No Operation (NOP)
                  STATE <= FETCH;
                WHEN "000001" =>       -- LOAD
                  STATE <= EX_LOAD;
                WHEN "000010" =>       -- STORE
                  STATE <= EX_STORE;
                WHEN "000011" =>       -- ADD
                  STATE <= EX_ADD;
                WHEN "000101" =>       -- JUMP
                  STATE <= EX_JUMP;
                WHEN "001001" =>       -- AND
                  STATE <= EX_AND;
				WHEN "000100" =>
				  STATE <= EX_SUB;
				WHEN "000110" =>
				  STATE <= EX_JNEG;
				WHEN "000111" =>
				  STATE <= EX_JPOS;
				WHEN "001000" =>
				  STATE <= EX_JZERO;
				WHEN "001010" =>
				  STATE <= EX_OR;
				WHEN "001011" =>
				  STATE <= EX_XOR;
				WHEN "001101" =>
				  STATE <= EX_ADDI;
				WHEN "001100" =>
				  STATE <= EX_SHIFT;
				WHEN "010000" =>
				  STATE <= EX_CALL;
				WHEN "010001" =>
				  STATE <= EX_RETURN;
				WHEN "010010" =>
				  STATE <= EX_IN;
				WHEN "010011" =>
				  STATE <= EX_OUT;
				  IO_WRITE_INT <= '1';
                WHEN OTHERS =>
                  STATE <= FETCH;      -- Invalid opcodes default to NOP
              END CASE;

            WHEN EX_LOAD =>
              AC    <= MDR;            -- Latch data from MDR (memory contents) to AC
              STATE <= FETCH;

            WHEN EX_STORE =>
              MW    <= '1';            -- Raise MW to write AC to MEM
              STATE <= EX_STORE2;

            WHEN EX_STORE2 =>
              MW    <= '0';            -- Drop MW to end write cycle
              STATE <= FETCH;

            WHEN EX_ADD =>
              AC    <= AC + MDR;
              STATE <= FETCH;

            WHEN EX_JUMP =>
              PC    <= IR(9 DOWNTO 0);
              STATE <= FETCH;
              
            WHEN EX_AND =>
              AC    <= AC AND MDR;
              STATE <= FETCH;
              
            WHEN EX_SUB =>
			  AC 	<= AC - MDR;
			  STATE <= FETCH;
			
			WHEN EX_JNEG =>
				IF AC(15) = '1' THEN
					PC 	<= IR(9 DOWNTO 0);
				END IF;
				STATE <= FETCH;
			
			WHEN EX_JZERO =>
				IF AC = "0000000000000000" THEN
					PC 	<= IR(9 DOWNTO 0);
				END IF;
				STATE <= FETCH;
				
			WHEN EX_JPOS =>
				IF AC /= "0000000000000000" THEN
					IF AC(15) = '0' THEN
						PC 	<= IR(9 DOWNTO 0);
					END IF;	
				END IF;
				STATE <= FETCH;
					
			WHEN EX_OR =>
			  AC 	<= AC OR MDR;
			  STATE <= FETCH;
			  
			WHEN EX_XOR =>
			  AC 	<= AC XOR MDR;
			  STATE <= FETCH;
			  
			WHEN EX_ADDI =>
					AC 	<= AC + (IR(9)&IR(9)&IR(9)&IR(9)&IR(9)&IR(9)&IR(9 DOWNTO 0));				
				STATE <= FETCH;
				
			WHEN EX_SHIFT =>
				AC <= AC_SHIFTED;
				STATE <= FETCH;
				
			WHEN EX_CALL =>
				PC_STACK  <= PC;
				PC		  <= IR(9 DOWNTO 0);
				STATE <= FETCH;
				
			WHEN EX_RETURN =>
				PC <= PC_STACK;
				STATE <= FETCH;
			 
			WHEN EX_IN =>
				AC <= IO_DATA;
				STATE <= FETCH;
			
			WHEN EX_OUT =>
				IO_WRITE_INT  <= '1';
				STATE <= EX_OUT2;
					
			WHEN EX_OUT2 =>
				IO_WRITE_INT  <= '0';
				STATE <= FETCH;
			  

            WHEN OTHERS =>
              STATE <= FETCH;          -- If an invalid state is reached, return to FETCH
          END CASE;
        END IF;
      END PROCESS;
  END a;
