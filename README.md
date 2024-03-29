﻿
# utils
This is a repository for some little, nifty and useful utilities that I
decided to develop for MSX. There are some Unix-like utilities, and some
utilities which can take advantage of [Nextor](https://github.com/Konamiman/Nextor). 
All of them are written in Turbo Pascal 3.0, using libraries developed by 
[Kari Lammassaari](http://pascal.hansotten.com/delphi/turbo-pascal-on-cpm-msx-dos-and-ms-dos/) 
and [PopolonY2K](https://sourceforge.net/projects/oldskooltech/). 
All the libraries are stripped to the minimum (MSX doesn't have plenty of RAM to
play with), they are in this repository and has the .INC extension in its names.

Note: All the commands' parameters can be known using the /h parameter (from *h*elp).

## pwd
Returns the current path. 
> 'nuff said.

## shuf
Shuffles the lines fron a given file. 
> I decided to do it first, because of the challenge and I can use most 
> of the adquired knowledge into other utilities. 

## grep
Search for patterns into a given file.
> It uses the Boyer-Moore string search algorithm, which is really fast,
> even for an old 3,58 Mhz Z80. Amazing! TODO: It finds the first occurrence 
> of a string into the line. We need to show all matches.

## cat
Sends a file to the standard output.

## tac
Sends a file in reverse order to the standard output.
> Unfortunately, I don't know if there's a way of speed up the file read,
> 'cause Pascal textfiles read routines can't use seek functions. So, I
> won't change the code.

## rev
Reverse lines characterwise.
> 'nuff said.

## head
Prints the first n lines (or n bytes) from a given file. If you doesn't use any
parameters, it will print the first ten lines.

## tail
Prints the last n lines (or n bytes) from a given file. If you doesn't use any
parameters, it will print the last ten lines.

## wc
Counts how many bytes, characters, words and lines from a given file. If you
doesn't use any parameters, it will print lines, words and bytes.

## sleep
## ttime (time)

## dos2unix
## unix2dos
## drvhelp
## devhelp
## maphelp
## lsblk
## zeroaloc
Sets reduced allocation information mode for any drives in Nextor. Faster
and more useful than RALLOC.

[Here you can download a ZIP package with all COM files.](https://github.com/ricardojpinheiro/utils/blob/master/utils.zip)

# TODO
All of them demands optimization, in order to use bigger files in a faster
way. I'll do it in the future. 

# Version notes.
(c) 2020-2024 Brazilian MSX Crew. Some rights reserved, but it's released due to
the GPL license, so... You know. Suggestions, corrections and upgrades are
welcome. But if you think that *all my work is garbage and I should learn Z80
Assembly because you think it's better*... GTH (Go To Hell). BTW, I'd send
your opinion to `/dev/null`.
