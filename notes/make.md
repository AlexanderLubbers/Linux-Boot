# Make notes
This file contains mistakes I have made while using make and also info that I found useful
## Make variables versus shell variables
* make variables = $(...) / $(shell ...)
* make variables get evaluated by make not the shell itself
* make evaluates the variables so the shell never even sees $(name). it just sees the result
* when you want to pass a literal into a shell, like say for example a command like "FILE_SIZE=$$(wc -c < bin/loader.bin)" then you use $$