on run
	tell application "Terminal"
		activate
		do script "HUMAN_SHELL_STATUS=failures HUMAN_SHELL_LAUNCHER=1 exec /bin/zsh -l"
	end tell
end run
