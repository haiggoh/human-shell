on run
	launchHumanShell("HUMAN_SHELL_STATUS=all HUMAN_SHELL_LAUNCHER=1 exec /bin/zsh -l")
end run

-- Open exactly one window. Launching Terminal makes it open a window of its
-- own, so when Terminal was not already running that window is reused instead
-- of being left behind as a stray vanilla shell next to the Human Shell.
on launchHumanShell(launchCommand)
	set terminalWasRunning to false
	tell application "System Events"
		if (exists process "Terminal") then set terminalWasRunning to true
	end tell

	tell application "Terminal"
		activate

		if terminalWasRunning then
			do script launchCommand
		else
			-- Wait briefly for Terminal's own startup window, then take it over.
			-- If it never appears, fall back to opening a window explicitly.
			set attemptsLeft to 100
			repeat while attemptsLeft > 0 and (count of windows) = 0
				delay 0.05
				set attemptsLeft to attemptsLeft - 1
			end repeat

			if (count of windows) > 0 then
				do script launchCommand in window 1
			else
				do script launchCommand
			end if
		end if
	end tell
end launchHumanShell
