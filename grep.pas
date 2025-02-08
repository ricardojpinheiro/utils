program grep;
{
* Print lines that match patterns.
* Lots of comments!
* }

{$i d:types.inc}
{$i d:memory.inc}
{$i d:dos.inc}
{$i d:dos2err.inc}
{$i d:dos2file.inc}
{$i d:fastwrit.inc}
{$i d:blink.inc}

Const
    b = 251;
    Limit = 255;

type
    BMTable  = array[0..Limit] of byte;
{
Type
    TFourStates = (After, Before, Middle, Nothing);
}
Var
    MSXDOSversion: TMSXDOSVersion;
    InputFileName: TFileName;
    TemporaryNumber: string[8];
    hInputFileName, nDrive: byte;
    hInputFile: text;
    Position, Counter, PositionsInOutputString, ValReturn: integer;
    i, j, MaxMatchLines, Lines: integer;
    Character: char;
    EndOfFile, Count, Found, Ignore, LineNumber, Reverse, ExtendedMode: boolean;
    Registers: TRegs;
{
    FourStates: TFourStates;
}    
    ForegroundColor:    Byte Absolute    $F3E9; { Foreground color }
    BackgroundColor:    Byte Absolute    $F3EA; { Background color }
    BorderColor:        Byte Absolute    $F3EB; { Border color }
    
    Temporary, OutputString, PrintString, Pattern: TString;
    
    BMT, Buffer: BMTable;

(* Finds the last occurence of a chat into a string. *)

function LastPos(Character: char; Phrase: TString): integer;
var
    i: integer;
    Found: boolean;
begin
    i := length(Phrase);
    Found := false;
    repeat
        if Phrase[i] = Character then
        begin
            LastPos := i + 1;
            Found := true;
        end;
        i := i - 1;
    until Found = true;
    if Not Found then LastPos := 0;
end;

(* Here we use the APPEND environment variable. *)

procedure CheatAPPEND (FileName: TFileName);
var
    FirstTwoDotsFound, LastBackSlashFound: byte;
    APPEND: string[7];
    Path, Temporary: TFileName;
begin

(* Initializing some variables... *)

    fillchar(Path, sizeof(Path), ' ' );
    fillchar(Temporary, sizeof(Temporary), ' ' );
    APPEND[0] := 'A';   APPEND[1] := 'P';   APPEND[2] := 'P';
    APPEND[3] := 'E';   APPEND[4] := 'N';   APPEND[5] := 'D';
    APPEND[6] := #0;
    
(*  Sees if in the path there is a ':', used with drive letter. *)    
    
    FirstTwoDotsFound := Pos (chr(58), FileName);

(*  If there is a two dots...  *)
    
    if FirstTwoDotsFound <> 0 then
    begin
    
(*  Let me see where is the last backslash character...  *)

        LastBackSlashFound := LastPos (chr(92), FileName);
        Path := copy (FileName, 1, LastBackSlashFound);

(*  Copy the path to the variable. *)
        
        for i := 1 to LastBackSlashFound - 1 do
            Temporary[i - 1] := Path[i];
        Temporary[LastBackSlashFound] := #0;
        Path := Temporary;

(*  Sets the APPEND environment variable. *)
        
        with Registers do
        begin
            B := sizeof (Path);
            C := ctSetEnvironmentItem;
            HL := addr (APPEND);
            DE := addr (Path);
        end;
        MSXBDOS (Registers);
    end;
end;

(* Here we use MSX-DOS 2 to do the error handling. *)

procedure ErrorCode (ExitsOrNot: boolean);
var
    ErrorCodeNumber: byte;
    ErrorMessage: TMSXDOSString;
    
begin
    ErrorCodeNumber := GetLastErrorCode;
    GetErrorMessage (ErrorCodeNumber, ErrorMessage);
    WriteLn (ErrorMessage);
    if ExitsOrNot = true then exit;
end;
 
(*  Command help.*)

procedure GrepHelp;
begin
    clrscr;
    fastwriteln('Usage: grep <pattern> <file> <params>.');
    fastwriteln('print lines that match patterns.');
    fastwriteln('Pattern: Text to be found.');
    fastwriteln('File: Text file.');
    fastwriteln('Parameters: ');
{    
    fastwriteln('/a<X> - Print X lines of trailing');
    fastwriteln('context after matching lines.');
    fastwriteln('/b<X> - Print X lines of trailing');
    fastwriteln('context before matching lines.');
    fastwriteln('/c<X> - Print X lines of output');
    fastwriteln('context.');
}     
    fastwriteln('/h - Display this help & exit.');
    fastwriteln('/i - Ignore case distinctions.');
    fastwriteln('/m<X> - Stop reading a file after X');
    fastwriteln('matching lines.');
    fastwriteln('/n - Prefix each line of output with');
    fastwriteln('its line number.');
    fastwriteln('/o - Print a count of matching lines');
    fastwriteln('for the input file.');
    fastwriteln('/r - Print non-matching lines.');
    fastwriteln('/v - Output version information & exit.');
    fastwriteln('/z - Extended mode (MSX 2, 80 columns).');
    writeln;
    halt;
end;

(*  Command version.*)

procedure GrepVersion;
begin
    clrscr;
    fastwriteln('grep version 3.0'); 
    fastwriteln('Copyright (c) 2020 Brazilian MSX Crew.');
    fastwriteln('Some rights reserved.');
    writeln;
    fastwriteln('License GPLv3+: GNU GPL v. 3 or later ');
    fastwriteln('<https://gnu.org/licenses/gpl.html>');
    fastwriteln('This is free software: you are free to');
    fastwriteln('change and redistribute it. There is ');
    fastwriteln('NO WARRANTY to the extent permitted ');
    fastwriteln('by law.');
    writeln;
    halt;
end;

(* Create a Boyer-Moore index-table to be used. *)

procedure CreateBMTable (var BMT: BMTable; Pattern : TString; ExactCase : boolean);
var
    Index : byte;
begin
    fillchar(BMT, sizeof(BMT), length(Pattern));
    if ExactCase then
        for Index := 1 to length(Pattern) do
            Pattern[Index] := upcase(Pattern[Index]);
        for Index := 1 to length(Pattern) do
            BMT[ord(Pattern[Index])] := (length(Pattern) - Index);
end;

(* Boyer-Moore Search function. *)

function BoyerMoore (var BMT: BMTable; var Buffer; BufferSize: integer; Pattern: TString; ExactCase: boolean): integer;
var
    Buffer2 : array[1..Limit] of char absolute Buffer;
    Index1, Index2, PatternSize : integer;
begin

(* BoyerMoore returns 0 if BufferSize exceeds Limit. Only a precaution. *)

    if (BufferSize > Limit)  then
        begin
            BoyerMoore := 0;
            exit;
        end;
        
    PatternSize := length(Pattern);
    
    if ExactCase then
    begin
        for Index1 := 1 to BufferSize do
            if (Buffer2[Index1] > #96) and (Buffer2[Index1] < #123) then
                Buffer2[Index1] := chr(ord(Buffer2[Index1]) - 32);
        for Index1 := 1 to length(Pattern) do
            Pattern[Index1] := upcase(Pattern[Index1]);
    end;
    
    Index1 := PatternSize;
    Index2 := PatternSize;
    
    repeat
        if (Buffer2[Index1] = Pattern[Index2]) then
        begin
            Index1 := Index1 - 1;
            Index2 := Index2 - 1;
        end
        else
        begin
            if (succ(PatternSize - Index2) > (BMT[ord(Buffer2[Index1])])) then
                Index1 := Index1 + succ(PatternSize - Index2)
            else
                Index1 := Index1 + BMT[ord(Buffer2[Index1])];
            Index2 := PatternSize;
        end;
    until (Index2 < 1) or (Index1 > BufferSize);
    
    if (Index1 > BufferSize) then
      BoyerMoore := 0
    else
      BoyerMoore := succ(Index1);
end;

procedure PrintGrep;
var
    k: integer;
    
    procedure WriteGrep (l: integer);
    var
        Factor: Byte;
    begin
    
(* Slight adjust to be used in Extended mode. *)
    
        Factor := Length(PrintString) div 80;
        
(* Removes the first character, which is a space. *)        
        
        delete(PrintString, 1, 1);
        
(* /n - Line number. *)        
        
        if LineNumber = true then
        begin
            fillchar(TemporaryNumber, sizeof(TemporaryNumber), ' ' );
            str(l, TemporaryNumber);
            TemporaryNumber := TemporaryNumber + ':';

(* /z - Extended mode. *)            
            
            if ExtendedMode = false then
                writeln(TemporaryNumber, PrintString)
            else
            begin
                PrintString := concat (TemporaryNumber, PrintString);
                fastwriteln(PrintString);
                if Reverse = false then
                    Blink(Position + Length(TemporaryNumber) - 2, WhereY - (Factor + 1), Length(Pattern));
            end;
        end
        else
            if ExtendedMode = false then
            begin
                writeln(PrintString);
            end
            else
            begin
                fastwriteln(PrintString);
                if Reverse = false then
                    Blink(Position - 2, WhereY - (Factor + 1), Length(Pattern));
            end;
    end;

begin

(* Counts how many matches does it had. *)

    Counter := Counter + 1;
    if Count = false then
    
(* The FourStates variable aren't being used - /a<x>, /b<x> and /c<x> isn't implemented. 
* Maybe in the future... *)    
{
        case FourStates of
            After: for k := i to i + Lines do
                        WriteGrep(k);
            Before: for k := i - Lines to i do
                        WriteGrep(k);
            Middle: for k := (i - Lines) to (i + Lines) do
                        WriteGrep(k);
            Nothing: WriteGrep(Lines);
        end;
}        
        WriteGrep(Lines);
end;

begin
(*  Initializing some variables. *)
    nDrive := 0;
    Character := ' ';
    Counter := 0;
    Count := false;
    Found := false;
    Ignore := false;
    LineNumber := false;
    Reverse := false;
    Position := 0;
    MaxMatchLines := maxint;
{
    FourStates := Nothing;
}
    ExtendedMode := false;
    EndOfFile := false;
    fillchar(InputFileName, sizeof(InputFileName), ' ' );
    ClearAllBlinks;

(*  if are we not running in a MSX-DOS 2 machine, exits. 
*   Else... Runs the program. *)

    GetMSXDOSVersion (MSXDOSversion);

    if (MSXDOSversion.nKernelMajor < 2) then
    begin
        fastwriteln('MSX-DOS 1.x not supported.');
        halt;
    end
    else 
    begin

(*  No parameters, command prints the help. *)
        if paramcount = 0 then GrepHelp;

(*  The first parameter should be the pattern. *)
        Pattern := paramstr(1);

(*  The second parameter should be the file. *)
        InputFileName := paramstr(2);

(*  Read parameters, and upcase them. *)
        for i := 1 to paramcount do
        begin
            Temporary := paramstr(i);
            for j := 1 to length(Temporary) do
                Temporary[j] := upcase(Temporary[j]);
            Character := Temporary[2];
            if Temporary[1] = '/' then
            begin
                delete(Temporary, 1, 2);

(*  Parameters. *)

                case Character of
{                
                    'A': FourStates := After;
                    'B': FourStates := Before;
                    'C': FourStates := Middle;
}
                    'H': GrepHelp;
                    'I': Ignore := true;
                    'M': Val(Temporary, MaxMatchLines, ValReturn);
                    'N': LineNumber := true;
                    'O': Count := true;
                    'R': Reverse := true;                        
                    'V': GrepVersion;
                    'Z': ExtendedMode := true;
                end;
{                
                if FourStates <> Nothing then Val(Temporary, Lines, ValReturn);
}
            end;
        end;

(*  Cheats the APPEND environment variable. *)

        CheatAPPEND(InputFileName);

(*  Open file *)

        hInputFileName := FileOpen (InputFileName, 'r');

(*  if there is any problem regarding the opening process, show the error code. *)

        if (hInputFileName in [ctInvalidFileHandle, ctInvalidOpenMode]) then ErrorCode (true);

        assign (hInputFile, InputFileName);
        reset (hInputFile);

(*  Set blink conditions. *)

        if ExtendedMode = true then
        begin
            ClearAllBlinks;
            SetBlinkColors(BackgroundColor, ForegroundColor);
            SetBlinkRate(15, 0);
            clrscr;
        end;

(*  Read file. Main loop. *)

        Lines := 0;
        while Not EndOfFile do
        begin
            EndOfFile := EOF(hInputFile);
            fillchar(PrintString, sizeof(PrintString), ' ' );
            
            readln (hInputFile, PrintString);
            insert(chr(32), PrintString, 1);
            OutputString := PrintString;
            Lines := Lines + 1;

(*  /i - Case insensitive. *)

            if Ignore = true then
            begin
                for i := 1 to Length(Pattern) do
                    Pattern[i] := upcase(Pattern[i]);
                for i := 1 to Length(OutputString) do
                    OutputString[i] := upcase(OutputString[i]);
            end;
        
            PositionsInOutputString := length(PrintString);
            fillchar(BMT, sizeof(BMT), 0);
            fillchar(Buffer, sizeof(Buffer), 0);
            
            for i := 1 to Length(OutputString) do
                Buffer[i] := ord(OutputString[i]);

            CreateBMTable(BMT, Pattern, Ignore);
            Position := BoyerMoore(BMT, Buffer, PositionsInOutputString, Pattern, Ignore);

(*  /r - If reverse mode is activated or not. *)
            
            case Reverse of
                false: if Position <> 0 then PrintGrep;
                true: if Position = 0 then PrintGrep;
            end;

(*  /m<x> - If matched lines exceeds the maximum, then ends the process. *)
            
            if Counter >= MaxMatchLines then EndOfFile := true;

        end;

(*  /o - only gives how many ocurrences. *)

        if Count = true then 
        begin
            str(Counter, Temporary);
            if ExtendedMode = true then fastwriteln(Temporary)
                else writeln(Temporary);
        end;

(*  /z - If extended mode is activated, then we wait for a key *)

        if ExtendedMode = true then
        begin
            read(kbd, Character);
            if Character <> ' ' then ClearAllBlinks;
        end;
        
(*  Close file. *)

        CheatAPPEND(' ');
        if (not FileClose(hInputFileName)) then ErrorCode(true);
        close(hInputFile);
    end;
end.
