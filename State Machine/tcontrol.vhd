--
--
-- State machine to control trains
--
--

LIBRARY IEEE;
USE  IEEE.STD_LOGIC_1164.all;
USE  IEEE.STD_LOGIC_ARITH.all;
USE  IEEE.STD_LOGIC_UNSIGNED.all;


ENTITY Tcontrol IS
	PORT(
		reset, clock, sensor1, sensor2      : IN std_logic;
		sensor3, sensor4, sensor5, sensor6  : IN std_logic;
		switch1, switch2, switch3, switch4  : OUT std_logic;
		dirA, dirB                          : OUT std_logic_vector(1 DOWNTO 0)
	);
END Tcontrol;


ARCHITECTURE a OF Tcontrol IS
	-- We create a new TYPE called STATE_TYPE that is only allowed
	-- to have the values specified here. This
	-- 1) allows us to use helpful names for values instead of
	--    arbitrary values
	-- 2) ensures that we can never accidentally set a signal of
	--    this type to an invalid value, and 
	-- 3) helps the synthesis software create efficient hardware for our design.
	TYPE STATE_TYPE IS (
		ABout,
		Ain,
		Bin,
		Astop,
		Bstop
	);
	-- Now we can create a signal of our new type.  Note that there is
	-- nothing special about the names "state" or "state_type", but it makes
	-- sense to use these names because that is how we are using them.
	SIGNAL state                                : STATE_TYPE;
	-- Here we create some new internal signals which will be concatenations
	-- of some of the sensor signals.  This will make CASE statements easier.
	SIGNAL sensor12, sensor13, sensor24         : std_logic_vector(1 DOWNTO 0);

BEGIN
	-- A process statement is required for clocked logic, such as a state machine.
	PROCESS (clock, reset)
	BEGIN
		IF reset = '1' THEN
			-- Reset to this state
			state <= ABout;
		ELSIF clock'EVENT AND clock = '1' THEN
			-- Case statement to determine next state.
			-- Case statements are a nice, clean way to make decisions
			-- based on different values of a signal.
			CASE state IS
				WHEN ABout =>
					CASE Sensor12 IS
						WHEN "00" => state <= ABout;
						WHEN "01" => state <= Bin;
						WHEN "10" => state <= Ain;
						WHEN "11" => state <= Ain;
						WHEN OTHERS => state <= ABout;
					END CASE;

				WHEN Ain =>
						CASE Sensor24 IS
						WHEN "00" => state <= Ain;
						WHEN "01" => state <= ABout;
						WHEN "10" => state <= Bstop;
						WHEN "11" => state <= Bin;
						WHEN OTHERS => state <= Ain;
					END CASE;

				WHEN Bin =>
					CASE Sensor13 IS
						WHEN "00" => state <= Bin;
						WHEN "01" => state <= ABout;
						WHEN "10" => state <= Astop;
						WHEN "11" => state <= Ain;
						WHEN OTHERS => state <= Bin;
					END CASE;

				WHEN Astop =>
					IF Sensor3 = '1' THEN
						state <= Ain;
					ELSE
						state <= Astop;
					END IF;

				WHEN Bstop =>
					IF Sensor4 = '1' THEN
						state <= Bin;
					ELSE
						state <= Bstop;
					END IF;

			END CASE;
		END IF;
	END PROCESS;

	-- Notice that all of the following logic is NOT in a process block,
	-- and thus does not depend on any clock.  Everything here is pure combinational
	-- logic, and exists in parallel with everything else.
	
	-- Combine bits for the internal signals declared above.
	-- ("&" operator concatenates bits)
	sensor12 <= sensor1 & sensor2;
	sensor13 <= sensor1 & sensor3;
	sensor24 <= sensor2 & sensor4;

	-- The following outputs depend on the state.
	WITH state SELECT Switch1 <=
		'0' WHEN ABout,
		'0' WHEN Ain,
		'1' WHEN Bin,
		'1' WHEN Astop,
		'0' WHEN Bstop;
	WITH state SELECT Switch2 <=
		'0' WHEN ABout,
		'0' WHEN Ain,
		'1' WHEN Bin,
		'1' WHEN Astop,
		'0' WHEN Bstop;
	WITH state SELECT DirA <=
		"01" WHEN ABout,
		"01" WHEN Ain,
		"01" WHEN Bin,
		"00" WHEN Astop,
		"01" WHEN Bstop;
	WITH state SELECT DirB <=
		"01" WHEN ABout,
		"01" WHEN Ain,
		"01" WHEN Bin,
		"01" WHEN Astop,
		"00" WHEN Bstop;
	
	-- These outputs happen to be constant values for this solution;
	-- they do not depend on the state.
	Switch3 <= '0';
	Switch4 <= '0';

END a;


