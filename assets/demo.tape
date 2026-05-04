Output assets/demo.gif

Set Shell "zsh"
Set FontSize 14
Set Width 1100
Set Height 620
Set Theme "Catppuccin Mocha"
Set TypingSpeed 40ms
Set PlaybackSpeed 1.0
Set Padding 20

Hide
Type 'export PATH="/Users/cyberjack/cowork/apps/local-llm/bin:$PATH"'
Enter
Type 'clear'
Enter
Sleep 500ms
Show

Type "local-llm models"
Sleep 400ms
Enter
Sleep 1500ms

Type "local-llm switch daily"
Sleep 400ms
Enter
Sleep 3s

Type 'local-llm prompt "List three Python HTTP libraries, one per line, no preamble."'
Sleep 400ms
Enter
Sleep 7s

Type "local-llm switch code"
Sleep 400ms
Enter
Sleep 5s

Type 'local-llm prompt "Write a Python one-liner that reverses a string."'
Sleep 400ms
Enter
Sleep 7s

Type "local-llm stop"
Sleep 400ms
Enter
Sleep 1500ms
